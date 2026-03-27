/// Sealed error hierarchy for all update engine failure modes.
///
/// Use an exhaustive switch for handling — the compiler enforces all cases:
/// ```dart
/// switch (error) {
///   case NetworkError(:final message) => ...,
///   case HashMismatch(:final filePath) => ...,
///   case NoPlatformEntry(:final message) => ...,
///   case IncompatibleVersion(:final message) => ...,
///   case RestartFailed(:final message) => ...,
/// }
/// ```
///
/// This set is CLOSED — adding a 6th subtype is a breaking
/// change (major version). [NoPlatformEntry] covers App Sandbox
/// incompatibility as well as missing platform channel
/// implementations.
sealed class UpdateError implements Exception {
  /// Creates an [UpdateError] with a required [message]
  /// and an optional [cause].
  const UpdateError({required this.message, this.cause});

  /// Human-readable description of the failure.
  final String message;

  /// The underlying exception or error that caused this failure, if any.
  final Object? cause;
}

/// Network failure during update info fetch or file download.
final class NetworkError extends UpdateError {
  /// Creates a [NetworkError] with a [message] and optional [cause].
  const NetworkError({required super.message, super.cause});
}

/// Blake2b hash of a downloaded file does not match the expected hash.
final class HashMismatch extends UpdateError {
  /// Creates a [HashMismatch] for the given [filePath] with a [message] and
  /// optional [cause].
  const HashMismatch({
    required super.message,
    required this.filePath,
    super.cause,
  });

  /// The file whose hash did not match the expected value.
  final String filePath;
}

/// No platform channel entry found, or the app is running inside App Sandbox.
final class NoPlatformEntry extends UpdateError {
  /// Creates a [NoPlatformEntry] with a [message] and optional [cause].
  const NoPlatformEntry({required super.message, super.cause});
}

/// The remote build number is not newer than the installed build number.
final class IncompatibleVersion extends UpdateError {
  /// Creates an [IncompatibleVersion] with a [message] and optional [cause].
  const IncompatibleVersion({required super.message, super.cause});
}

/// Native restart sequence failed — file copy or process relaunch error.
final class RestartFailed extends UpdateError {
  /// Creates a [RestartFailed] with a [message] and optional [cause].
  const RestartFailed({required super.message, super.cause});
}
