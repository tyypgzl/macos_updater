import 'package:macos_updater/src/models/update_info.dart';

/// Sealed result type returned by the update check function.
///
/// Use an exhaustive switch — no default arm needed:
/// ```dart
/// switch (result) {
///   case UpToDate() => showUpToDateMessage(),
///   case ForceUpdateRequired(:final info) => showMandatoryUpdateUI(info),
///   case OptionalUpdateAvailable(:final info) => promptDownload(info),
/// }
/// ```
sealed class UpdateCheckResult {
  /// Creates an [UpdateCheckResult].
  const UpdateCheckResult();
}

/// The installed app is current — no update is available.
final class UpToDate extends UpdateCheckResult {
  /// Creates an [UpToDate] result.
  const UpToDate();
}

/// The installed version is below the minimum required version.
///
/// The consumer MUST prompt the user to update — the app cannot continue
/// on the current version. [info] contains version metadata and the list
/// of changed files to download.
final class ForceUpdateRequired extends UpdateCheckResult {
  /// Creates a [ForceUpdateRequired] result with the given update [info].
  const ForceUpdateRequired(this.info);

  /// Version metadata and changed files for the mandatory update.
  final UpdateInfo info;
}

/// An update is available but the current version meets the minimum.
///
/// The consumer may offer the user a choice to update or skip.
/// [info] contains version metadata and the list of changed files to download.
final class OptionalUpdateAvailable extends UpdateCheckResult {
  /// Creates an [OptionalUpdateAvailable] result with the given update [info].
  const OptionalUpdateAvailable(this.info);

  /// Version metadata and changed files for the optional update.
  final UpdateInfo info;
}
