import 'dart:io';

import 'package:desktop_updater/desktop_updater_platform_interface.dart';
import 'package:desktop_updater/src/engine/file_downloader.dart';
import 'package:desktop_updater/src/engine/file_hasher.dart' as hasher;
import 'package:desktop_updater/src/errors/update_check_result.dart';
import 'package:desktop_updater/src/errors/update_error.dart';
import 'package:desktop_updater/src/models/file_hash.dart';
import 'package:desktop_updater/src/models/update_info.dart';
import 'package:desktop_updater/src/models/update_progress.dart';
import 'package:desktop_updater/src/update_source.dart';

/// Checks whether an update is available by querying the given [source].
///
/// Returns `UpToDate` when the source returns `null`
/// or the remote build number is not greater than the installed build.
///
/// Returns `UpdateAvailable` with a populated `UpdateInfo.changedFiles`
/// list (diff of local vs remote SHA-256 hashes) when the remote build
/// number exceeds the locally installed build number.
///
/// Any exception thrown by the source is caught and wrapped in a
/// `NetworkError` — no raw exception escapes this function.
Future<UpdateCheckResult> checkForUpdate(UpdateSource source) async {
  try {
    final remoteInfo = await source.getLatestUpdateInfo();
    if (remoteInfo == null) {
      return const UpToDate();
    }

    final localBuild =
        await DesktopUpdaterPlatform.instance.getCurrentVersion();
    if (remoteInfo.buildNumber <= localBuild) {
      return const UpToDate();
    }

    final localHashes = await hasher.generateLocalFileHashes();
    final remoteHashes =
        await source.getRemoteFileHashes(remoteInfo.remoteBaseUrl);
    final changedFiles = hasher.diffFileHashes(localHashes, remoteHashes);

    return UpdateAvailable(remoteInfo.copyWith(changedFiles: changedFiles));
  } catch (e) {
    throw NetworkError(
      message: 'checkForUpdate failed: $e',
      cause: e,
    );
  }
}

/// Downloads the changed files described in [info] from the remote server.
///
/// Streams download progress events to [onProgress] as each chunk arrives.
/// When the `changedFiles` list in [info] is empty, the future
/// completes immediately
/// without invoking [onProgress].
///
/// Files are staged in the app's update directory, which is resolved
/// relative to `Platform.resolvedExecutable`. On macOS this is
/// `MyApp.app/Contents/update/`.
///
/// Stream errors (e.g. `NetworkError`, `HashMismatch`) are re-thrown as
/// exceptions so the caller can handle them uniformly via try/catch.
Future<void> downloadUpdate(
  UpdateInfo info, {
  void Function(UpdateProgress)? onProgress,
}) async {
  final appDir = File(Platform.resolvedExecutable).parent.parent.path;

  final stream = downloadFiles(
    remoteBaseUrl: info.remoteBaseUrl,
    changedFiles: info.changedFiles,
    appDir: appDir,
  );

  await for (final progress in stream) {
    onProgress?.call(progress);
  }
}

/// Restarts the app to apply the downloaded update.
///
/// Delegates to the platform interface's `restartApp`, which
/// invokes the native platform restart sequence.
///
/// Throws `RestartFailed` if the platform call throws any exception.
Future<void> applyUpdate() async {
  try {
    await DesktopUpdaterPlatform.instance.restartApp();
  } catch (e) {
    throw RestartFailed(
      message: 'applyUpdate failed: $e',
      cause: e,
    );
  }
}

/// Computes SHA-256 hashes for all files in the running app bundle.
///
/// Pass [path] to override `Platform.resolvedExecutable` — used in tests
/// to point at a temp directory instead of the real app bundle.
///
/// Throws [NoPlatformEntry] if the resolved directory does not exist.
Future<List<FileHash>> generateLocalFileHashes({String? path}) {
  return hasher.generateLocalFileHashes(path: path);
}
