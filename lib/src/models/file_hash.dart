import "package:flutter/foundation.dart";

/// Represents a file path and its Blake2b hash, used for delta comparison
/// between the local app bundle and the remote update.
///
/// JSON keys intentionally differ from Dart field names to maintain
/// backward compatibility with hashes.json produced by the CLI tools:
/// - JSON "path" → Dart filePath
/// - JSON "calculatedHash" → Dart hash
/// - JSON "length" → Dart length
@immutable
final class FileHash {
  /// Creates a [FileHash] with the given file path, hash, and length.
  const FileHash({
    required this.filePath,
    required this.hash,
    required this.length,
  });

  /// Creates a [FileHash] from a JSON map produced by the CLI hashes.json.
  ///
  /// Expects keys: "path", "calculatedHash", "length".
  factory FileHash.fromJson(Map<String, dynamic> json) {
    return FileHash(
      filePath: json["path"] as String,
      hash: json["calculatedHash"] as String,
      length: json["length"] as int,
    );
  }

  /// The relative file path within the app bundle.
  final String filePath;

  /// The Blake2b hash of the file contents.
  final String hash;

  /// The size of the file in bytes.
  final int length;

  /// Serialises this instance to the JSON format expected by hashes.json.
  Map<String, dynamic> toJson() {
    return {
      "path": filePath,
      "calculatedHash": hash,
      "length": length,
    };
  }

  /// Returns a copy of this [FileHash] with the specified fields replaced.
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
