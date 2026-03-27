import 'package:desktop_updater/src/errors/update_error.dart';
import 'package:desktop_updater/src/models/file_hash.dart';
import 'package:desktop_updater/src/models/update_info.dart';

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
///   Future<UpdateInfo?> getLatestUpdateInfo() async {
///     final config = FirebaseRemoteConfig.instance;
///     await config.fetchAndActivate();
///     final build = config.getInt("build_number");
///     if (build == 0) return null;
///     return UpdateInfo(
///       version: config.getString("version"),
///       buildNumber: build,
///       remoteBaseUrl: config.getString("remote_base_url"),
///       changedFiles: const [],
///     );
///   }
///
///   @override
///   Future<List<FileHash>> getRemoteFileHashes(String remoteBaseUrl) async {
///     final response = await http.get(Uri.parse("$remoteBaseUrl/hashes.json"));
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
/// a typed [UpdateError] subtype. Consumers do NOT need to throw [UpdateError].
abstract interface class UpdateSource {
  /// Returns the latest [UpdateInfo] from the consumer's backend,
  /// or `null` if the app is already up-to-date.
  ///
  /// The engine calls this to determine whether an update is available.
  /// Pass an [UpdateInfo] with an empty [UpdateInfo.changedFiles] list —
  /// the engine populates that field via hash diffing.
  Future<UpdateInfo?> getLatestUpdateInfo();

  /// Returns the list of all remote file hashes for the given [remoteBaseUrl].
  ///
  /// The engine passes [UpdateInfo.remoteBaseUrl] as [remoteBaseUrl].
  /// Implementations should fetch the `hashes.json` produced by the CLI
  /// and parse each entry using [FileHash.fromJson].
  Future<List<FileHash>> getRemoteFileHashes(String remoteBaseUrl);
}
