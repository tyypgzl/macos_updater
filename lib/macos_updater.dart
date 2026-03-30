/// Public API barrel for the macos_updater package.
///
/// Exports the v2 engine API functions (`checkForUpdate`, `downloadUpdate`,
/// `applyUpdate`, `generateLocalFileHashes`) and all supporting types.
///
/// Consumers import this file only — no other package imports needed.
library;

export 'package:macos_updater/src/errors/update_check_result.dart';
export 'package:macos_updater/src/errors/update_error.dart';
export 'package:macos_updater/src/macos_updater_api.dart';
export 'package:macos_updater/src/models/file_hash.dart';
export 'package:macos_updater/src/models/platform_update_details.dart';
export 'package:macos_updater/src/models/update_details.dart';
export 'package:macos_updater/src/models/update_info.dart';
export 'package:macos_updater/src/models/update_progress.dart';
export 'package:macos_updater/src/update_source.dart';
