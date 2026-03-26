import "package:desktop_updater/desktop_updater_platform_interface.dart";
import "package:desktop_updater/src/app_archive.dart";
import "package:desktop_updater/src/file_hash.dart";
import "package:desktop_updater/src/prepare.dart";
import "package:desktop_updater/src/update.dart";
import "package:desktop_updater/src/update_progress.dart";
import "package:desktop_updater/src/version_check.dart";

export "package:desktop_updater/src/app_archive.dart";
export "package:desktop_updater/src/errors/update_check_result.dart";
export "package:desktop_updater/src/errors/update_error.dart";
export "package:desktop_updater/src/localization.dart";
export "package:desktop_updater/src/models/file_hash.dart";
export "package:desktop_updater/src/models/update_info.dart";
// UpdateProgress from src/models re-exported below once v1 export is removed in Phase 5.
// ignore: unused_shown_name
export "package:desktop_updater/src/models/update_progress.dart" hide UpdateProgress;
export "package:desktop_updater/src/update_progress.dart";
export "package:desktop_updater/widget/update_dialog.dart";
export "package:desktop_updater/widget/update_direct_card.dart";
export "package:desktop_updater/widget/update_sliver.dart";

export "desktop_updater_inherited_widget.dart";

class DesktopUpdater {
  DesktopUpdater();
  Future<String?> getPlatformVersion() {
    return DesktopUpdaterPlatform.instance.getPlatformVersion();
  }

  Future<String?> sayHello() {
    return Future.value("Hello from DesktopUpdater!");
  }

  /// Uygulamayı kapatır ve yeniden başlatır
  Future<void> restartApp() {
    return DesktopUpdaterPlatform.instance.restartApp();
  }

  Future<String?> getExecutablePath() {
    return DesktopUpdaterPlatform.instance.getExecutablePath();
  }

  Future<List<FileHashModel?>> verifyFileHash(
    String oldHashFilePath,
    String newHashFilePath,
  ) {
    return verifyFileHashes(oldHashFilePath, newHashFilePath);
  }

  Future<String?> generateFileHashes({String? path}) {
    return genFileHashes(path: path);
  }

  Future<Stream<UpdateProgress>> updateApp({
    required String remoteUpdateFolder,
    required List<FileHashModel?> changedFiles,
  }) {
    return updateAppFunction(
      remoteUpdateFolder: remoteUpdateFolder,
      changes: changedFiles,
    );
  }

  Future<List<FileHashModel?>> prepareUpdateApp({
    required String remoteUpdateFolder,
  }) {
    return prepareUpdateAppFunction(remoteUpdateFolder: remoteUpdateFolder);
  }

  Future<int> getCurrentVersion() {
    return DesktopUpdaterPlatform.instance.getCurrentVersion();
  }

  Future<ItemModel?> versionCheck({
    required String appArchiveUrl,
  }) {
    return versionCheckFunction(appArchiveUrl: appArchiveUrl);
  }
}
