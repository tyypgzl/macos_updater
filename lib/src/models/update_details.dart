import 'package:flutter/foundation.dart';
import 'package:macos_updater/src/models/platform_update_details.dart';

// Sentinel object used to distinguish "not provided" from "explicitly null"
// in copyWith for nullable fields.
const Object _sentinel = Object();

/// Platform-specific update configuration returned by the update source.
///
/// Maps directly to the top-level JSON structure:
/// ```json
/// { "macos": { "minimum": "1.0.1", "latest": "1.0.2", "active": true } }
/// ```
///
/// Only [macos] is actively used; additional platform fields (ios, android)
/// are reserved for future use.
@immutable
final class UpdateDetails {
  /// Creates an [UpdateDetails] with optional platform configs.
  const UpdateDetails({
    this.macos,
    this.remoteBaseUrl,
  });

  /// macOS-specific update configuration, or `null` if not provided.
  final PlatformUpdateDetails? macos;

  /// Base URL for the update CDN, used to fetch remote file hashes.
  ///
  /// Passed to the engine when fetching remote file hashes.
  /// `null` means no remote base URL is provided.
  final String? remoteBaseUrl;

  /// Returns a copy with the specified fields replaced.
  UpdateDetails copyWith({
    Object? macos = _sentinel,
    Object? remoteBaseUrl = _sentinel,
  }) {
    return UpdateDetails(
      macos: identical(macos, _sentinel)
          ? this.macos
          : macos as PlatformUpdateDetails?,
      remoteBaseUrl: identical(remoteBaseUrl, _sentinel)
          ? this.remoteBaseUrl
          : remoteBaseUrl as String?,
    );
  }
}
