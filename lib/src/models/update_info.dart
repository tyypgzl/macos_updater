import 'package:flutter/foundation.dart';
import 'package:macos_updater/src/models/file_hash.dart';

// Sentinel object used to distinguish "not provided" from "explicitly null"
// in copyWith for nullable fields.
const Object _sentinel = Object();

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
    this.isMandatory = false,
    this.minBuildNumber,
    this.releaseNotes,
  });

  /// Human-readable version string, for display only.
  final String version;

  /// Integer build number used for version comparison.
  /// A remote [buildNumber] greater than the local value
  /// means an update exists.
  final int buildNumber;

  /// Base URL where update files are hosted. Used by the engine to
  /// construct per-file download URLs.
  final String remoteBaseUrl;

  /// Files that differ between the local bundle and the remote version.
  /// Populated by the engine; consumers pass this to the download function.
  final List<FileHash> changedFiles;

  /// Whether the update is mandatory and the user cannot skip it.
  ///
  /// Set by the engine when [minBuildNumber] is non-null and the local
  /// build is below that threshold. Consumers may also set this directly
  /// from their backend data. Defaults to `false`.
  final bool isMandatory;

  /// The minimum build number that clients must be running to continue.
  ///
  /// When the engine detects that the local build number is less than this
  /// value, it sets [isMandatory] to `true` on the returned update info.
  /// `null` means no minimum threshold is enforced.
  final int? minBuildNumber;

  /// Human-readable release notes for this update, for display only.
  ///
  /// `null` when the source does not provide release notes.
  final String? releaseNotes;

  /// Returns a copy of this [UpdateInfo] with the specified fields replaced.
  ///
  /// For nullable fields ([minBuildNumber], [releaseNotes]), passing `null`
  /// explicitly will clear the field. Omitting the parameter leaves the
  /// existing value unchanged.
  UpdateInfo copyWith({
    String? version,
    int? buildNumber,
    String? remoteBaseUrl,
    List<FileHash>? changedFiles,
    bool? isMandatory,
    Object? minBuildNumber = _sentinel,
    Object? releaseNotes = _sentinel,
  }) {
    return UpdateInfo(
      version: version ?? this.version,
      buildNumber: buildNumber ?? this.buildNumber,
      remoteBaseUrl: remoteBaseUrl ?? this.remoteBaseUrl,
      changedFiles: changedFiles ?? this.changedFiles,
      isMandatory: isMandatory ?? this.isMandatory,
      minBuildNumber: identical(minBuildNumber, _sentinel)
          ? this.minBuildNumber
          : minBuildNumber as int?,
      releaseNotes: identical(releaseNotes, _sentinel)
          ? this.releaseNotes
          : releaseNotes as String?,
    );
  }
}
