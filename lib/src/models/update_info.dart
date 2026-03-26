import "package:desktop_updater/src/models/file_hash.dart";
import "package:flutter/foundation.dart";

/// Metadata about an available update, returned by the UpdateSource.
///
/// [version] is a human-readable display string (e.g. "2.1.0") — not used
/// for comparison. [buildNumber] is the integer used for version comparison:
/// remote.buildNumber > local means an update is available.
///
/// [changedFiles] is populated by the engine after diffing local vs remote
/// hashes. It represents only the files that need to be downloaded.
@immutable
final class UpdateInfo {
  /// Creates an [UpdateInfo] with the given version metadata and changed files.
  const UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.remoteBaseUrl,
    required this.changedFiles,
  });

  /// Human-readable version string, for display only.
  final String version;

  /// Integer build number used for version comparison.
  /// A remote [buildNumber] greater than the local value means an update exists.
  final int buildNumber;

  /// Base URL where update files are hosted. Used by the engine to
  /// construct per-file download URLs.
  final String remoteBaseUrl;

  /// Files that differ between the local bundle and the remote version.
  /// Populated by the engine; consumers pass this to the download function.
  final List<FileHash> changedFiles;

  /// Returns a copy of this [UpdateInfo] with the specified fields replaced.
  UpdateInfo copyWith({
    String? version,
    int? buildNumber,
    String? remoteBaseUrl,
    List<FileHash>? changedFiles,
  }) {
    return UpdateInfo(
      version: version ?? this.version,
      buildNumber: buildNumber ?? this.buildNumber,
      remoteBaseUrl: remoteBaseUrl ?? this.remoteBaseUrl,
      changedFiles: changedFiles ?? this.changedFiles,
    );
  }
}
