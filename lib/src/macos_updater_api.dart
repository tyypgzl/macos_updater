import 'dart:developer' as developer;
import 'dart:io';

import 'package:macos_updater/macos_updater_platform_interface.dart';
import 'package:macos_updater/src/engine/file_downloader.dart';
import 'package:macos_updater/src/engine/file_hasher.dart' as hasher;
import 'package:macos_updater/src/errors/update_check_result.dart';
import 'package:macos_updater/src/errors/update_error.dart';
import 'package:macos_updater/src/models/file_hash.dart';
import 'package:macos_updater/src/models/update_info.dart';
import 'package:macos_updater/src/models/update_progress.dart';
import 'package:macos_updater/src/update_source.dart';
import 'package:pub_semver/pub_semver.dart';

void _log(String message, {bool enabled = false}) {
  if (enabled) {
    developer.log(message, name: 'macos_updater');
  }
}

/// Checks whether an update is available by querying
/// the given [source].
///
/// Returns [UpToDate] when the source returns `null`,
/// when the macOS platform details are absent, when
/// the platform is inactive, or when the installed
/// version is already at or ahead of the latest.
///
/// Returns [ForceUpdateRequired] when the installed
/// version is below the minimum required version.
///
/// Returns [OptionalUpdateAvailable] when the installed
/// version is at or above the minimum but below latest.
///
/// Set [enableLogging] to `true` to log each step
/// via `dart:developer` (visible in DevTools / console).
///
/// Pass [localHashesPath] to override
/// `Platform.resolvedExecutable` for tests.
Future<UpdateCheckResult> checkForUpdate(
  UpdateSource source, {
  String? localHashesPath,
  bool enableLogging = false,
}) async {
  try {
    _log('→ getUpdateDetails()', enabled: enableLogging);
    final details = await source.getUpdateDetails();
    _log(
      '← details: $details, '
      'macos: ${details?.macos}, '
      'remoteBaseUrl: ${details?.remoteBaseUrl}',
      enabled: enableLogging,
    );

    if (details == null) {
      _log('✗ details is null → UpToDate', enabled: enableLogging);
      return const UpToDate();
    }

    final platformDetails = details.macos;
    if (platformDetails == null) {
      _log('✗ macos is null → UpToDate', enabled: enableLogging);
      return const UpToDate();
    }

    _log(
      '  platform: minimum=${platformDetails.minimum}, '
      'latest=${platformDetails.latest}, '
      'active=${platformDetails.active}, '
      'url=${platformDetails.url}',
      enabled: enableLogging,
    );

    if (!platformDetails.active) {
      _log('✗ not active → UpToDate', enabled: enableLogging);
      return const UpToDate();
    }

    _log('→ getCurrentVersion()', enabled: enableLogging);
    final currentVersionStr =
        await MacosUpdaterPlatform.instance.getCurrentVersion();
    _log(
      '← currentVersion: "$currentVersionStr"',
      enabled: enableLogging,
    );

    final currentVersion = Version.parse(currentVersionStr);
    final minimumVersion =
        Version.parse(platformDetails.minimum);
    final latestVersion =
        Version.parse(platformDetails.latest);

    _log(
      '  parsed: current=$currentVersion, '
      'minimum=$minimumVersion, '
      'latest=$latestVersion',
      enabled: enableLogging,
    );

    if (currentVersion >= latestVersion) {
      _log('✓ current >= latest → UpToDate', enabled: enableLogging);
      return const UpToDate();
    }

    final remoteBaseUrl =
        platformDetails.url ?? details.remoteBaseUrl ?? '';
    _log(
      '  remoteBaseUrl: "$remoteBaseUrl"',
      enabled: enableLogging,
    );

    _log('→ generateLocalFileHashes()', enabled: enableLogging);
    final localHashes = await hasher.generateLocalFileHashes(
      path: localHashesPath,
    );
    _log(
      '← ${localHashes.length} local hashes',
      enabled: enableLogging,
    );

    _log('→ getRemoteFileHashes()', enabled: enableLogging);
    final remoteHashes = await source.getRemoteFileHashes(
      remoteBaseUrl,
    );
    _log(
      '← ${remoteHashes.length} remote hashes',
      enabled: enableLogging,
    );

    final changedFiles =
        hasher.diffFileHashes(localHashes, remoteHashes);
    _log(
      '  ${changedFiles.length} files changed',
      enabled: enableLogging,
    );

    final info = UpdateInfo(
      version: platformDetails.latest,
      remoteBaseUrl: remoteBaseUrl,
      changedFiles: changedFiles,
      minimumVersion: platformDetails.minimum,
    );

    if (currentVersion < minimumVersion) {
      _log(
        '⚠ current < minimum → ForceUpdateRequired',
        enabled: enableLogging,
      );
      return ForceUpdateRequired(info);
    }

    _log(
      '↑ OptionalUpdateAvailable',
      enabled: enableLogging,
    );
    return OptionalUpdateAvailable(info);
  } catch (e, st) {
    _log(
      '✗ ERROR: $e\n$st',
      enabled: enableLogging,
    );
    throw NetworkError(
      message: 'checkForUpdate failed: $e',
      cause: e,
    );
  }
}

/// Downloads the changed files described in [info].
///
/// Streams progress events to [onProgress].
/// When `changedFiles` is empty, completes immediately.
///
/// Set [enableLogging] to `true` to log progress.
Future<void> downloadUpdate(
  UpdateInfo info, {
  void Function(UpdateProgress)? onProgress,
  bool enableLogging = false,
}) async {
  final appDir =
      File(Platform.resolvedExecutable).parent.parent.path;

  _log(
    '→ downloadFiles: '
    '${info.changedFiles.length} files, '
    'appDir=$appDir',
    enabled: enableLogging,
  );

  final stream = downloadFiles(
    remoteBaseUrl: info.remoteBaseUrl,
    changedFiles: info.changedFiles,
    appDir: appDir,
  );

  await for (final progress in stream) {
    _log(
      '  ${progress.completedFiles}/${progress.totalFiles} '
      '${progress.currentFile}',
      enabled: enableLogging,
    );
    onProgress?.call(progress);
  }

  _log('✓ download complete', enabled: enableLogging);
}

/// Restarts the app to apply the downloaded update.
///
/// Throws [RestartFailed] if the platform call throws.
Future<void> applyUpdate() async {
  try {
    await MacosUpdaterPlatform.instance.restartApp();
  } catch (e) {
    throw RestartFailed(
      message: 'applyUpdate failed: $e',
      cause: e,
    );
  }
}

/// Computes SHA-256 hashes for all files in the running
/// app bundle.
///
/// Pass [path] to override `Platform.resolvedExecutable`.
///
/// Throws [NoPlatformEntry] if the directory doesn't
/// exist.
Future<List<FileHash>> generateLocalFileHashes({
  String? path,
}) {
  return hasher.generateLocalFileHashes(path: path);
}
