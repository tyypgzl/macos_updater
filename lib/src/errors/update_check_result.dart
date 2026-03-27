import 'package:desktop_updater/src/models/update_info.dart';

/// Sealed result type returned by the update check function.
///
/// Use an exhaustive switch — no default arm needed:
/// ```dart
/// switch (result) {
///   case UpToDate() => showUpToDateMessage(),
///   case UpdateAvailable(:final info) => promptDownload(info),
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

/// An update is available. [info] contains version metadata and
/// the list of changed files to download.
final class UpdateAvailable extends UpdateCheckResult {
  /// Creates an [UpdateAvailable] result with the given update [info].
  const UpdateAvailable(this.info);

  /// Version metadata and changed files for the available update.
  final UpdateInfo info;
}
