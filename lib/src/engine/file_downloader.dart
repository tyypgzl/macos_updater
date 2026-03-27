import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography_plus/cryptography_plus.dart';
import 'package:desktop_updater/src/errors/update_error.dart';
import 'package:desktop_updater/src/models/file_hash.dart';
import 'package:desktop_updater/src/models/update_progress.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

/// Downloads a single file from [url] into [stagingPath], calling
/// [onChunk] with the number of bytes received in each chunk.
///
/// After the file is written, re-hashes it using Blake2b and compares
/// against [expectedHash]. Throws [HashMismatch] if they differ.
///
/// Throws [NetworkError] on non-200 HTTP response.
Future<void> _downloadSingleFile(
  http.Client client,
  String url,
  String stagingPath,
  void Function(int chunkBytes) onChunk,
  String expectedHash,
) async {
  final request = http.Request('GET', Uri.parse(url));
  final response = await client.send(request);

  if (response.statusCode != 200) {
    throw NetworkError(
      message:
          'Failed to download file: $url (HTTP ${response.statusCode})',
    );
  }

  final saveDir = Directory(path.dirname(stagingPath));
  if (!saveDir.existsSync()) {
    await saveDir.create(recursive: true);
  }

  final sink = File(stagingPath).openWrite();
  try {
    await response.stream
        .listen(
          (List<int> chunk) {
            sink.add(chunk);
            onChunk(chunk.length);
          },
          cancelOnError: true,
        )
        .asFuture<void>();
  } finally {
    await sink.close();
  }

  // Post-download hash verification.
  final fileBytes = await File(stagingPath).readAsBytes();
  final hash = await Blake2b().hash(fileBytes);
  final actualHash = base64.encode(hash.bytes);

  if (actualHash != expectedHash) {
    throw HashMismatch(
      message:
          'Hash mismatch for $stagingPath: '
          'expected $expectedHash, got $actualHash',
      filePath: stagingPath,
    );
  }
}

/// Downloads [changedFiles] from [remoteBaseUrl] into the app's staging
/// directory, emitting [UpdateProgress] events on the returned stream.
///
/// The stream is a broadcast stream and closes when all downloads complete
/// or when an error occurs. All errors appear as stream error events —
/// this function does not throw directly.
///
/// The [http.Client] is closed in a `whenComplete` handler on all code
/// paths.
///
/// Pass an [http.Client] via the optional [client] parameter to inject
/// a mock client in tests. Production code uses the default internal client.
Stream<UpdateProgress> downloadFiles({
  required String remoteBaseUrl,
  required List<FileHash> changedFiles,
  required String appDir,
  http.Client? client,
}) {
  final controller = StreamController<UpdateProgress>.broadcast();

  if (changedFiles.isEmpty) {
    controller.close();
    return controller.stream;
  }

  final totalBytes = changedFiles.fold<double>(
    0,
    (sum, f) => sum + f.length,
  );
  final totalFiles = changedFiles.length;
  var receivedBytes = 0.0;
  var completedFiles = 0;
  final resolvedClient = client ?? http.Client();

  Future<void> downloadOne(FileHash file) async {
    try {
      await _downloadSingleFile(
        resolvedClient,
        '$remoteBaseUrl/${file.filePath}',
        path.join(appDir, 'update', file.filePath),
        (chunkBytes) {
          receivedBytes += chunkBytes;
          controller.add(
            UpdateProgress(
              totalBytes: totalBytes,
              receivedBytes: receivedBytes,
              currentFile: file.filePath,
              totalFiles: totalFiles,
              completedFiles: completedFiles,
            ),
          );
        },
        file.hash,
      );
      completedFiles += 1;
      controller.add(
        UpdateProgress(
          totalBytes: totalBytes,
          receivedBytes: receivedBytes,
          currentFile: file.filePath,
          totalFiles: totalFiles,
          completedFiles: completedFiles,
        ),
      );
    } on Object catch (error, stackTrace) {
      controller.addError(error, stackTrace);
    }
  }

  final futures = [
    for (final file in changedFiles) downloadOne(file),
  ];

  unawaited(
    Future.wait(futures).whenComplete(() async {
      resolvedClient.close();
      await controller.close();
    }),
  );

  return controller.stream;
}
