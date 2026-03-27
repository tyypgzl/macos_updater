import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:desktop_updater/src/errors/update_error.dart';
import 'package:desktop_updater/src/models/file_hash.dart';

/// Returns the app bundle's Contents/ directory on macOS, or the
/// executable's parent directory on other platforms.
///
/// On macOS, `Platform.resolvedExecutable` points to
/// `MyApp.app/Contents/MacOS/MyApp`, so one `parent` call reaches
/// `MyApp.app/Contents/`, which is the bundle root.
///
/// Pass [overridePath] in tests to avoid reading `Platform.resolvedExecutable`.
Directory _resolveAppContentsDir([String? overridePath]) {
  final executablePath = overridePath ?? Platform.resolvedExecutable;
  final directoryPath = executablePath.substring(
    0,
    executablePath.lastIndexOf(Platform.pathSeparator),
  );
  var dir = Directory(directoryPath);
  if (Platform.isMacOS) {
    dir = dir.parent;
  }
  return dir;
}

/// Computes SHA-256 hashes for all files in the running app bundle.
///
/// Uses `Platform.resolvedExecutable` to locate the bundle root.
/// On macOS the executable is inside `Contents/MacOS/` so one `parent`
/// call resolves to the `Contents/` root used for hashing and staging.
///
/// Pass [path] to override `Platform.resolvedExecutable` — used in tests
/// to point at a temp directory instead of the real app bundle.
///
/// Throws [NoPlatformEntry] if the resolved directory does not exist.
Future<List<FileHash>> generateLocalFileHashes({String? path}) async {
  final dir = _resolveAppContentsDir(path);

  if (!dir.existsSync()) {
    throw NoPlatformEntry(
      message: 'Desktop Updater: Bundle directory does not exist: ${dir.path}',
    );
  }

  final hashList = <FileHash>[];

  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is File) {
      final fileBytes = await entity.readAsBytes();
      final digest = sha256.convert(fileBytes);
      final hashString = base64.encode(digest.bytes);
      final relativePath = entity.path.substring(dir.path.length + 1);

      if (hashString.isNotEmpty) {
        hashList.add(
          FileHash(
            filePath: relativePath,
            hash: hashString,
            length: entity.lengthSync(),
          ),
        );
      }
    }
  }

  return hashList;
}

/// Returns the subset of [remoteHashes] that differ from [localHashes].
///
/// A file is considered changed if it is absent from [localHashes] or
/// if its [FileHash.hash] differs from the local entry with the same
/// [FileHash.filePath].
///
/// Both [localHashes] and [remoteHashes] are non-nullable [List<FileHash>].
List<FileHash> diffFileHashes(
  List<FileHash> localHashes,
  List<FileHash> remoteHashes,
) {
  final localByPath = {
    for (final h in localHashes) h.filePath: h,
  };
  return [
    for (final remote in remoteHashes)
      if (localByPath[remote.filePath]?.hash != remote.hash) remote,
  ];
}
