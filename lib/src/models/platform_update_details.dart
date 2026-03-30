import 'package:flutter/foundation.dart';

/// Configuration for a specific platform's update requirements.
///
/// Maps directly to the JSON structure:
/// ```json
/// { "minimum": "1.0.1", "latest": "1.0.2", "active": true }
/// ```
@immutable
final class PlatformUpdateDetails {
  /// Creates a [PlatformUpdateDetails] for a platform.
  const PlatformUpdateDetails({
    required this.minimum,
    required this.latest,
    required this.active,
  });

  /// The minimum version clients must run (semver string, e.g. "1.0.1").
  /// Clients below this version receive a force-update result.
  final String minimum;

  /// The latest available version (semver string, e.g. "1.0.2").
  /// Clients below this version (but at or above [minimum]) receive an
  /// optional-update result.
  final String latest;

  /// Whether this platform's update channel is currently active.
  ///
  /// When `false`, update checks return an up-to-date result regardless of
  /// the current version.
  final bool active;

  /// Returns a copy with the specified fields replaced.
  PlatformUpdateDetails copyWith({
    String? minimum,
    String? latest,
    bool? active,
  }) {
    return PlatformUpdateDetails(
      minimum: minimum ?? this.minimum,
      latest: latest ?? this.latest,
      active: active ?? this.active,
    );
  }
}
