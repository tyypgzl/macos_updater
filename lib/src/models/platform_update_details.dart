import 'package:flutter/foundation.dart';

/// Configuration for a specific platform's update requirements.
///
/// Maps directly to the JSON structure:
/// ```json
/// {
///   "minimum": "1.0.1",
///   "latest": "1.0.2",
///   "active": true,
///   "url": "https://server.com/updates/1.0.2"
/// }
/// ```
@immutable
final class PlatformUpdateDetails {
  /// Creates a [PlatformUpdateDetails] for a platform.
  const PlatformUpdateDetails({
    required this.minimum,
    required this.latest,
    required this.active,
    this.url,
  });

  /// The minimum version clients must run
  /// (semver string, e.g. '1.0.1').
  /// Clients below this version receive a force-update result.
  final String minimum;

  /// The latest available version
  /// (semver string, e.g. '1.0.2').
  /// Clients below this version (but at or above [minimum])
  /// receive an optional-update result.
  final String latest;

  /// Whether this platform's update channel is active.
  ///
  /// When `false`, update checks return an up-to-date
  /// result regardless of the current version.
  final bool active;

  /// Base URL where update files are hosted for this
  /// platform.
  ///
  /// Used by the engine to fetch remote file hashes and
  /// download changed files. Falls back to
  /// `UpdateDetails.remoteBaseUrl` if `null`.
  final String? url;

  /// Returns a copy with the specified fields replaced.
  PlatformUpdateDetails copyWith({
    String? minimum,
    String? latest,
    bool? active,
    Object? url = _sentinel,
  }) {
    return PlatformUpdateDetails(
      minimum: minimum ?? this.minimum,
      latest: latest ?? this.latest,
      active: active ?? this.active,
      url: identical(url, _sentinel)
          ? this.url
          : url as String?,
    );
  }
}

// Sentinel for nullable copyWith fields.
const Object _sentinel = Object();
