import "package:macos_updater/src/models/file_hash.dart";
import "package:macos_updater/src/models/update_info.dart";
import "package:macos_updater/src/models/update_progress.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("FileHash", () {
    test("copyWith with no arguments returns equal instance", () {
      const original = FileHash(
        filePath: "Contents/MacOS/MyApp",
        hash: "abc123def456",
        length: 2048,
      );
      final copy = original.copyWith();
      expect(copy.filePath, original.filePath);
      expect(copy.hash, original.hash);
      expect(copy.length, original.length);
    });

    test("copyWith overrides only specified field", () {
      const original = FileHash(
        filePath: "Contents/MacOS/MyApp",
        hash: "abc123def456",
        length: 2048,
      );
      final copy = original.copyWith(hash: "newHash999");
      expect(copy.filePath, "Contents/MacOS/MyApp");
      expect(copy.hash, "newHash999");
      expect(copy.length, 2048);
    });

    test("fromJson round-trip preserves all fields", () {
      const original = FileHash(
        filePath: "Contents/Frameworks/libflutter.dylib",
        hash: "deadbeef",
        length: 99999,
      );
      final decoded = FileHash.fromJson(original.toJson());
      expect(decoded.filePath, original.filePath);
      expect(decoded.hash, original.hash);
      expect(decoded.length, original.length);
    });

    test("fromJson reads correct JSON keys", () {
      final fh = FileHash.fromJson(const {
        "path": "Contents/MacOS/Runner",
        "calculatedHash": "sha256abc",
        "length": 512,
      });
      expect(fh.filePath, "Contents/MacOS/Runner");
      expect(fh.hash, "sha256abc");
      expect(fh.length, 512);
    });

    test("toJson writes correct JSON keys", () {
      const fh = FileHash(filePath: "a/b/c", hash: "h1", length: 10);
      final json = fh.toJson();
      expect(json["path"], "a/b/c");
      expect(json["calculatedHash"], "h1");
      expect(json["length"], 10);
      expect(json.containsKey("filePath"), isFalse);
      expect(json.containsKey("hash"), isFalse);
    });
  });

  group("UpdateInfo", () {
    test("copyWith with no arguments returns equal instance", () {
      const file = FileHash(filePath: "a", hash: "h", length: 1);
      const original = UpdateInfo(
        version: "2.0.0",
        buildNumber: 200,
        remoteBaseUrl: "https://example.com/updates",
        changedFiles: [file],
      );
      final copy = original.copyWith();
      expect(copy.version, original.version);
      expect(copy.buildNumber, original.buildNumber);
      expect(copy.remoteBaseUrl, original.remoteBaseUrl);
      expect(copy.changedFiles, original.changedFiles);
    });

    test("copyWith overrides only specified field", () {
      const file = FileHash(filePath: "a", hash: "h", length: 1);
      const original = UpdateInfo(
        version: "2.0.0",
        buildNumber: 200,
        remoteBaseUrl: "https://example.com/updates",
        changedFiles: [file],
      );
      final copy = original.copyWith(buildNumber: 201);
      expect(copy.version, "2.0.0");
      expect(copy.buildNumber, 201);
      expect(copy.remoteBaseUrl, "https://example.com/updates");
      expect(copy.changedFiles, [file]);
    });
  });

  group("UpdateProgress", () {
    test("copyWith with no arguments returns equal instance", () {
      const original = UpdateProgress(
        totalBytes: 1000,
        receivedBytes: 500,
        currentFile: "libflutter.dylib",
        totalFiles: 3,
        completedFiles: 1,
      );
      final copy = original.copyWith();
      expect(copy.totalBytes, original.totalBytes);
      expect(copy.receivedBytes, original.receivedBytes);
      expect(copy.currentFile, original.currentFile);
      expect(copy.totalFiles, original.totalFiles);
      expect(copy.completedFiles, original.completedFiles);
    });

    test("copyWith overrides only specified field", () {
      const original = UpdateProgress(
        totalBytes: 1000,
        receivedBytes: 500,
        currentFile: "libflutter.dylib",
        totalFiles: 3,
        completedFiles: 1,
      );
      final copy = original.copyWith(completedFiles: 2, receivedBytes: 750);
      expect(copy.totalBytes, 1000);
      expect(copy.receivedBytes, 750);
      expect(copy.currentFile, "libflutter.dylib");
      expect(copy.totalFiles, 3);
      expect(copy.completedFiles, 2);
    });
  });
}
