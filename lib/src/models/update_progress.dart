import 'package:flutter/foundation.dart';

/// Represents the progress of a file download during an update.
///
/// Emitted by the update engine as a [Stream] of events. All byte values
/// are in bytes (not KB/MB) — consumers format for display.
@immutable
final class UpdateProgress {
  /// Creates an [UpdateProgress] snapshot with the given field values.
  const UpdateProgress({
    required this.totalBytes,
    required this.receivedBytes,
    required this.currentFile,
    required this.totalFiles,
    required this.completedFiles,
  });

  /// Total size in bytes of all files to be downloaded.
  final double totalBytes;

  /// Number of bytes received so far across all files.
  final double receivedBytes;

  /// The file currently being downloaded.
  final String currentFile;

  /// Total number of files to download in this update.
  final int totalFiles;

  /// Number of files fully downloaded so far.
  final int completedFiles;

  /// Returns a copy of this [UpdateProgress] with the
  /// specified fields replaced.
  UpdateProgress copyWith({
    double? totalBytes,
    double? receivedBytes,
    String? currentFile,
    int? totalFiles,
    int? completedFiles,
  }) {
    return UpdateProgress(
      totalBytes: totalBytes ?? this.totalBytes,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      currentFile: currentFile ?? this.currentFile,
      totalFiles: totalFiles ?? this.totalFiles,
      completedFiles: completedFiles ?? this.completedFiles,
    );
  }
}
