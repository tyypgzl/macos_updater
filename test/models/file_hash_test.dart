import "package:macos_updater/src/models/file_hash.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("FileHash", () {
    test("fromJson maps JSON keys correctly", () {
      final json = {
        "path": "foo/bar.dylib",
        "calculatedHash": "abc123",
        "length": 1024,
      };
      final fileHash = FileHash.fromJson(json);
      expect(fileHash.filePath, equals("foo/bar.dylib"));
      expect(fileHash.hash, equals("abc123"));
      expect(fileHash.length, equals(1024));
    });

    test("toJson produces correct keys", () {
      const fileHash = FileHash(
        filePath: "foo/bar.dylib",
        hash: "abc123",
        length: 1024,
      );
      final json = fileHash.toJson();
      expect(json["path"], equals("foo/bar.dylib"));
      expect(json["calculatedHash"], equals("abc123"));
      expect(json["length"], equals(1024));
    });

    test("round-trip: fromJson(toJson()) produces structurally equal instance", () {
      const original = FileHash(
        filePath: "Contents/MacOS/MyApp",
        hash: "deadbeef",
        length: 42,
      );
      final roundTripped = FileHash.fromJson(original.toJson());
      expect(roundTripped.filePath, equals(original.filePath));
      expect(roundTripped.hash, equals(original.hash));
      expect(roundTripped.length, equals(original.length));
    });

    test("copyWith with no arguments returns identical fields", () {
      const original = FileHash(
        filePath: "path/to/file",
        hash: "hashvalue",
        length: 100,
      );
      final copied = original.copyWith();
      expect(copied.filePath, equals(original.filePath));
      expect(copied.hash, equals(original.hash));
      expect(copied.length, equals(original.length));
    });

    test("copyWith overrides only specified fields", () {
      const original = FileHash(
        filePath: "path/to/file",
        hash: "hashvalue",
        length: 100,
      );
      final copied = original.copyWith(length: 200);
      expect(copied.filePath, equals(original.filePath));
      expect(copied.hash, equals(original.hash));
      expect(copied.length, equals(200));
    });
  });
}
