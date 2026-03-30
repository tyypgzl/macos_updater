import 'package:flutter/foundation.dart';
import 'package:macos_updater/src/models/file_hash.dart';

// Sentinel object used to distinguish "not provided" from "explicitly null"
// in copyWith for nullable fields.
const Object _sentinel = Object();

/// Metadata about an available update, produced by the engine after
/// comparing local and remote versions.
///
/// [version] is the semver string used for version comparison
/// (e.g. '1.0.2'). [changedFiles] is populated by the engine after
/// diffing local vs remote Blake2b hashes — it represents only the
/// files that need to be downloaded.
@immutable
final class UpdateInfo {
  /// Creates an [UpdateInfo] with the given version metadata and changed files.
  const UpdateInfo({
    required this.version,
    required this.remoteBaseUrl,
    required this.changedFiles,
    this.minimumVersion,
    this.releaseNotes,
  });

  /// Semver version string (e.g. '1.0.2'). Used by the engine for
  /// version comparison.
  final String version;

  /// Base URL where update files are hosted. Used by the engine to
  /// construct per-file download URLs.
  final String remoteBaseUrl;

  /// Files that differ between the local bundle and the remote version.
  /// Populated by the engine; consumers pass this to the download function.
  final List<FileHash> changedFiles;

  /// Minimum semver string clients must run. Clients below this threshold
  /// receive a force-update result. `null` means no minimum is enforced.
  final String? minimumVersion;

  /// Human-readable release notes for this update, for display only.
  ///
  /// `null` when the source does not provide release notes.
  final String? releaseNotes;

  /// Returns a copy of this [UpdateInfo] with the specified fields replaced.
  ///
  /// For nullable fields ([minimumVersion], [releaseNotes]), passing `null`
  /// explicitly will clear the field. Omitting the parameter leaves the
  /// existing value unchanged.
  UpdateInfo copyWith({
    String? version,
    String? remoteBaseUrl,
    List<FileHash>? changedFiles,
    Object? minimumVersion = _sentinel,
    Object? releaseNotes = _sentinel,
  }) {
    return UpdateInfo(
      version: version ?? this.version,
      remoteBaseUrl: remoteBaseUrl ?? this.remoteBaseUrl,
      changedFiles: changedFiles ?? this.changedFiles,
      minimumVersion: identical(minimumVersion, _sentinel)
          ? this.minimumVersion
          : minimumVersion as String?,
      releaseNotes: identical(releaseNotes, _sentinel)
          ? this.releaseNotes
          : releaseNotes as String?,
    );
  }
}
