import 'package:macos_updater/src/models/file_hash.dart';
import 'package:macos_updater/src/models/update_details.dart';

/// The backend abstraction for the update engine.
///
/// Implement this interface to connect any backend — REST API,
/// Firebase Remote Config, local files, etc. — without changing
/// engine internals.
///
/// Example:
/// ```dart
/// class FirebaseUpdateSource implements UpdateSource {
///   @override
///   Future<UpdateDetails?> getUpdateDetails() async {
///     final json = await fetchFromBackend();
///     final macosJson = json['macos'] as Map<String, dynamic>?;
///     if (macosJson == null) return null;
///     return UpdateDetails(
///       macos: PlatformUpdateDetails(
///         minimum: macosJson['minimum'] as String,
///         latest: macosJson['latest'] as String,
///         active: macosJson['active'] as bool,
///       ),
///       remoteBaseUrl: json['remoteBaseUrl'] as String?,
///     );
///   }
///
///   @override
///   Future<List<FileHash>> getRemoteFileHashes(String remoteBaseUrl) async {
///     final response =
///         await http.get(Uri.parse('$remoteBaseUrl/hashes.json'));
///     final list = jsonDecode(response.body) as List<dynamic>;
///     return list
///         .map((e) => FileHash.fromJson(
///               e as Map<String, dynamic>,
///             ))
///         .toList();
///   }
/// }
/// ```
///
/// Consumer implementations may throw any exception — the engine wraps
/// all [UpdateSource] calls in try-catch and maps unknown exceptions to
/// a typed `UpdateError` subtype. Consumers do NOT need to throw `UpdateError`.
abstract interface class UpdateSource {
  /// Returns platform-specific update configuration from the consumer's
  /// backend, or `null` if no update information is available.
  ///
  /// The engine reads [UpdateDetails.macos] to determine the minimum and latest
  /// versions for the current platform. Return `null` to signal up-to-date.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Future<UpdateDetails?> getUpdateDetails() async {
  ///   final json = await fetchFromBackend();
  ///   final macosJson = json['macos'] as Map<String, dynamic>?;
  ///   if (macosJson == null) return null;
  ///   return UpdateDetails(
  ///     macos: PlatformUpdateDetails(
  ///       minimum: macosJson['minimum'] as String,
  ///       latest: macosJson['latest'] as String,
  ///       active: macosJson['active'] as bool,
  ///     ),
  ///     remoteBaseUrl: json['remoteBaseUrl'] as String?,
  ///   );
  /// }
  /// ```
  Future<UpdateDetails?> getUpdateDetails();

  /// Returns the list of all remote file hashes for the given [remoteBaseUrl].
  ///
  /// The engine passes [UpdateDetails.remoteBaseUrl] as [remoteBaseUrl].
  /// Implementations should fetch the `hashes.json` produced by the CLI
  /// and parse each entry using [FileHash.fromJson].
  Future<List<FileHash>> getRemoteFileHashes(String remoteBaseUrl);
}
