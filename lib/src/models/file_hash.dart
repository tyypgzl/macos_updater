import 'package:meta/meta.dart';

/// Represents a file path and its SHA-256 hash, used
/// for delta comparison between the local app bundle
/// and the remote update.
///
/// JSON format:
/// ```json
/// { "filePath": "Contents/MacOS/Runner",
///   "hash": "base64...", "length": 12345 }
/// ```
@immutable
final class FileHash {
  /// Creates a [FileHash].
  const FileHash({
    required this.filePath,
    required this.hash,
    required this.length,
  });

  /// Creates a [FileHash] from a JSON map.
  factory FileHash.fromJson(
    Map<String, dynamic> json,
  ) {
    return FileHash(
      filePath: json['filePath'] as String,
      hash: json['hash'] as String,
      length: json['length'] as int,
    );
  }

  /// The relative file path within the app bundle.
  final String filePath;

  /// The SHA-256 hash of the file contents.
  final String hash;

  /// The size of the file in bytes.
  final int length;

  /// Serialises to JSON.
  Map<String, dynamic> toJson() {
    return {
      'filePath': filePath,
      'hash': hash,
      'length': length,
    };
  }

  /// Returns a copy with the specified fields replaced.
  FileHash copyWith({
    String? filePath,
    String? hash,
    int? length,
  }) {
    return FileHash(
      filePath: filePath ?? this.filePath,
      hash: hash ?? this.hash,
      length: length ?? this.length,
    );
  }
}
