import "dart:async";
import "dart:convert";
import "dart:io";

import "package:cryptography_plus/cryptography_plus.dart";
import "package:desktop_updater/src/engine/file_downloader.dart";
import "package:desktop_updater/src/errors/update_error.dart";
import "package:desktop_updater/src/models/file_hash.dart";
import "package:desktop_updater/src/models/update_progress.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

/// Computes the base64-encoded Blake2b hash of [bytes].
Future<String> _blake2bBase64(List<int> bytes) async {
  final hash = await Blake2b().hash(bytes);
  return base64.encode(hash.bytes);
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("file_downloader_test_");
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group("downloadFiles", () {
    test(
      "empty changedFiles closes stream immediately with no events",
      () async {
        final events = <UpdateProgress>[];
        final stream = downloadFiles(
          remoteBaseUrl: "https://example.com",
          changedFiles: const [],
          appDir: tempDir.path,
        );

        await stream.forEach(events.add);

        expect(events, isEmpty);
      },
    );

    test(
      "single file download emits progress events and completes",
      () async {
        final body = [1, 2, 3, 4, 5];
        final expectedHash = await _blake2bBase64(body);

        final mockClient = MockClient.streaming(
          (request, bodyStream) async => http.StreamedResponse(
            Stream.value(body),
            200,
            contentLength: body.length,
          ),
        );

        final fileHash = FileHash(
          filePath: "test_file.bin",
          hash: expectedHash,
          length: body.length,
        );

        final events = <UpdateProgress>[];
        final stream = downloadFiles(
          remoteBaseUrl: "https://example.com",
          changedFiles: [fileHash],
          appDir: tempDir.path,
          client: mockClient,
        );

        await stream.forEach(events.add);

        expect(events, isNotEmpty);
        final last = events.last;
        expect(last.completedFiles, 1);
        expect(last.totalFiles, 1);
        expect(last.totalBytes, body.length.toDouble());
      },
    );

    test(
      "receivedBytes accumulates across multiple chunks (not reset per chunk)",
      () async {
        final chunk1 = [1, 2, 3];
        final chunk2 = [4, 5, 6, 7];
        final allBytes = [...chunk1, ...chunk2];
        final expectedHash = await _blake2bBase64(allBytes);

        final bodyController = StreamController<List<int>>();

        final mockClient = MockClient.streaming(
          (request, bodyStream) async => http.StreamedResponse(
            bodyController.stream,
            200,
            contentLength: allBytes.length,
          ),
        );

        final fileHash = FileHash(
          filePath: "chunked_file.bin",
          hash: expectedHash,
          length: allBytes.length,
        );

        final events = <UpdateProgress>[];
        final stream = downloadFiles(
          remoteBaseUrl: "https://example.com",
          changedFiles: [fileHash],
          appDir: tempDir.path,
          client: mockClient,
        );

        // Start listening before emitting chunks.
        final done = stream.forEach(events.add);

        bodyController
          ..add(chunk1)
          ..add(chunk2);
        await bodyController.close();
        await done;

        // The final receivedBytes should be the sum of both chunks (7), NOT the
        // size of the last chunk alone (4). This directly tests the v1 bug fix.
        final chunkEvents =
            events.where((e) => e.completedFiles == 0).toList();
        expect(chunkEvents, isNotEmpty);
        // The last chunk-progress event before file completion must show
        // accumulated bytes equal to the total.
        expect(chunkEvents.last.receivedBytes, allBytes.length.toDouble());
      },
    );

    test(
      "HTTP 404 emits NetworkError on stream and stream still closes",
      () async {
        final mockClient = MockClient.streaming(
          (request, bodyStream) async =>
              http.StreamedResponse(const Stream.empty(), 404),
        );

        const fileHash = FileHash(
          filePath: "missing_file.bin",
          hash: "does_not_matter",
          length: 100,
        );

        Object? caughtError;
        final stream = downloadFiles(
          remoteBaseUrl: "https://example.com",
          changedFiles: [fileHash],
          appDir: tempDir.path,
          client: mockClient,
        );

        await stream.handleError((final Object e) {
          caughtError = e;
        }).drain<void>();

        expect(caughtError, isA<NetworkError>());
      },
    );

    test(
      "optional client parameter is used when provided",
      () async {
        final body = [10, 20, 30];
        final expectedHash = await _blake2bBase64(body);

        var mockWasCalled = false;
        final mockClient = MockClient.streaming(
          (request, bodyStream) async {
            mockWasCalled = true;
            return http.StreamedResponse(
              Stream.value(body),
              200,
              contentLength: body.length,
            );
          },
        );

        final fileHash = FileHash(
          filePath: "injected_client_file.bin",
          hash: expectedHash,
          length: body.length,
        );

        final stream = downloadFiles(
          remoteBaseUrl: "https://example.com",
          changedFiles: [fileHash],
          appDir: tempDir.path,
          client: mockClient,
        );

        await stream.drain<void>();

        expect(mockWasCalled, isTrue);
      },
    );

    test(
      "HashMismatch is emitted when downloaded file hash does not match",
      () async {
        final body = [1, 2, 3];
        // Provide a hash that deliberately does not match the body bytes.
        const wrongHash = "aGFzaF9taXNtYXRjaF90ZXN0";

        final mockClient = MockClient.streaming(
          (request, bodyStream) async => http.StreamedResponse(
            Stream.value(body),
            200,
            contentLength: body.length,
          ),
        );

        const fileHash = FileHash(
          filePath: "hash_mismatch_file.bin",
          hash: wrongHash,
          length: 3,
        );

        Object? caughtError;
        final stream = downloadFiles(
          remoteBaseUrl: "https://example.com",
          changedFiles: [fileHash],
          appDir: tempDir.path,
          client: mockClient,
        );

        await stream.handleError((final Object e) {
          caughtError = e;
        }).drain<void>();

        expect(caughtError, isA<HashMismatch>());
      },
    );
  });
}
