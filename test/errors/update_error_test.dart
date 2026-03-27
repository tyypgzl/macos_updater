import "package:desktop_updater/src/errors/update_error.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("UpdateError sealed hierarchy", () {
    test("NetworkError has message and optional cause", () {
      const error = NetworkError(message: "timeout");
      expect(error.message, equals("timeout"));
      expect(error.cause, isNull);
    });

    test("NetworkError with cause", () {
      final innerError = Exception("inner");
      final error = NetworkError(message: "failed", cause: innerError);
      expect(error.cause, equals(innerError));
    });

    test("HashMismatch carries filePath field", () {
      const error = HashMismatch(
        message: "hash mismatch",
        filePath: "Contents/MacOS/MyApp",
      );
      expect(error.filePath, equals("Contents/MacOS/MyApp"));
      expect(error.message, equals("hash mismatch"));
    });

    test("NoPlatformEntry can be constructed const", () {
      const error = NoPlatformEntry(message: "no platform entry");
      expect(error.message, equals("no platform entry"));
      expect(error.cause, isNull);
    });

    test("IncompatibleVersion can be constructed const", () {
      const error = IncompatibleVersion(message: "version mismatch");
      expect(error.message, equals("version mismatch"));
    });

    test("RestartFailed can be constructed const", () {
      const error = RestartFailed(message: "restart failed");
      expect(error.message, equals("restart failed"));
    });

    test("UpdateError implements Exception — can be thrown and caught", () {
      expect(
        () => throw const NetworkError(message: "test"),
        throwsA(isA<Exception>()),
      );
    });

    test("exhaustive switch compiles without default arm", () {
      // This test validates the sealed class is exhaustive.
      // If the switch is not exhaustive, Dart will fail to compile.
      const UpdateError error = NetworkError(message: "net");
      final result = switch (error) {
        NetworkError(:final message) => "network: $message",
        HashMismatch(:final filePath) => "hash: $filePath",
        NoPlatformEntry(:final message) => "no platform: $message",
        IncompatibleVersion(:final message) => "incompat: $message",
        RestartFailed(:final message) => "restart: $message",
      };
      expect(result, equals("network: net"));
    });

    test("switch correctly handles HashMismatch with filePath", () {
      const UpdateError error = HashMismatch(
        message: "bad hash",
        filePath: "/path/to/file",
      );
      final result = switch (error) {
        NetworkError() => "network",
        HashMismatch(:final filePath) => "hash: $filePath",
        NoPlatformEntry() => "no platform",
        IncompatibleVersion() => "incompat",
        RestartFailed() => "restart",
      };
      expect(result, equals("hash: /path/to/file"));
    });
  });
}
