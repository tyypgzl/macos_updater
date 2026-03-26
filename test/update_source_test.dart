import "package:desktop_updater/src/errors/update_error.dart";
import "package:desktop_updater/src/models/file_hash.dart";
import "package:desktop_updater/src/models/update_info.dart";
import "package:desktop_updater/src/update_source.dart";
import "package:flutter_test/flutter_test.dart";

// Minimal mock returning controlled fixtures.
class MockUpdateSource implements UpdateSource {
  MockUpdateSource({this.updateInfo, this.fileHashes = const []});

  final UpdateInfo? updateInfo;
  final List<FileHash> fileHashes;

  @override
  Future<UpdateInfo?> getLatestUpdateInfo() async => updateInfo;

  @override
  Future<List<FileHash>> getRemoteFileHashes(String remoteBaseUrl) async =>
      fileHashes;
}

// Implementation that throws a plain Exception — not an UpdateError.
// Verifies the engine error-boundary pattern: catch any exception and
// map to a typed UpdateError.
class ThrowingUpdateSource implements UpdateSource {
  @override
  Future<UpdateInfo?> getLatestUpdateInfo() =>
      Future.error(Exception("backend unavailable"));

  @override
  Future<List<FileHash>> getRemoteFileHashes(String remoteBaseUrl) =>
      Future.error(Exception("hash fetch failed"));
}

// Helper that simulates the engine error boundary pattern.
Future<T> withErrorBoundary<T>(Future<T> Function() call) async {
  try {
    return await call();
  } catch (e) {
    throw NetworkError(
      message: "UpdateSource error: $e",
      cause: e,
    );
  }
}

void main() {
  group("UpdateSource contract", () {
    group("MockUpdateSource", () {
      test("getLatestUpdateInfo returns null when up-to-date", () async {
        final source = MockUpdateSource();
        expect(await source.getLatestUpdateInfo(), isNull);
      });

      test("getLatestUpdateInfo returns configured UpdateInfo", () async {
        const info = UpdateInfo(
          version: "2.1.0",
          buildNumber: 210,
          remoteBaseUrl: "https://example.com/updates",
          changedFiles: [],
        );
        final source = MockUpdateSource(updateInfo: info);
        final result = await source.getLatestUpdateInfo();
        expect(result, isNotNull);
        expect(result!.version, "2.1.0");
        expect(result.buildNumber, 210);
        expect(result.remoteBaseUrl, "https://example.com/updates");
        expect(result.changedFiles, isEmpty);
      });

      test("getRemoteFileHashes returns configured file list", () async {
        const hashes = [
          FileHash(
            filePath: "Contents/MacOS/Runner",
            hash: "abc123",
            length: 4096,
          ),
          FileHash(
            filePath: "Contents/Frameworks/libflutter.dylib",
            hash: "def456",
            length: 8192,
          ),
        ];
        final source = MockUpdateSource(fileHashes: hashes);
        final result =
            await source.getRemoteFileHashes("https://example.com/updates");
        expect(result.length, 2);
        expect(result[0].filePath, "Contents/MacOS/Runner");
        expect(result[0].hash, "abc123");
        expect(result[1].filePath, "Contents/Frameworks/libflutter.dylib");
        expect(result[1].length, 8192);
      });

      test("getRemoteFileHashes returns empty list by default", () async {
        final source = MockUpdateSource();
        final result =
            await source.getRemoteFileHashes("https://example.com/updates");
        expect(result, isEmpty);
      });
    });

    group("error boundary pattern", () {
      test(
        "plain exception from getLatestUpdateInfo is mappable to NetworkError",
        () async {
          final source = ThrowingUpdateSource();
          expect(
            () => withErrorBoundary(source.getLatestUpdateInfo),
            throwsA(
              isA<NetworkError>().having(
                (e) => e.cause,
                "cause",
                isA<Exception>(),
              ),
            ),
          );
        },
      );

      test(
        "plain exception from getRemoteFileHashes is mappable to NetworkError",
        () async {
          final source = ThrowingUpdateSource();
          expect(
            () => withErrorBoundary(
              () => source.getRemoteFileHashes("https://example.com"),
            ),
            throwsA(
              isA<NetworkError>().having(
                (e) => e.message,
                "message",
                contains("UpdateSource error"),
              ),
            ),
          );
        },
      );
    });
  });
}
