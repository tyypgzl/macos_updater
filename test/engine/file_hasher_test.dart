import "dart:io";

import "package:desktop_updater/src/engine/file_hasher.dart";
import "package:desktop_updater/src/errors/update_error.dart";
import "package:desktop_updater/src/models/file_hash.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("diffFileHashes", () {
    test("empty local and non-empty remote returns all remote entries", () {
      const remote = [
        FileHash(filePath: "a", hash: "x", length: 1),
        FileHash(filePath: "b", hash: "y", length: 2),
      ];
      final result = diffFileHashes([], remote);
      expect(result, equals(remote));
    });

    test("identical local and remote returns empty list", () {
      const hashes = [
        FileHash(filePath: "a", hash: "x", length: 1),
      ];
      final result = diffFileHashes(hashes, hashes);
      expect(result, isEmpty);
    });

    test("same path but different hash returns remote entry", () {
      const local = [FileHash(filePath: "a", hash: "old", length: 1)];
      const remote = [FileHash(filePath: "a", hash: "new", length: 1)];
      final result = diffFileHashes(local, remote);
      expect(result.length, equals(1));
      expect(result.first.hash, equals("new"));
    });

    test("same path and same hash is not returned", () {
      const hashes = [FileHash(filePath: "a", hash: "x", length: 1)];
      final result = diffFileHashes(hashes, hashes);
      expect(result, isEmpty);
    });

    test("new file in remote not in local is returned", () {
      const local = [FileHash(filePath: "a", hash: "x", length: 1)];
      const remote = [
        FileHash(filePath: "a", hash: "x", length: 1),
        FileHash(filePath: "b", hash: "y", length: 2),
      ];
      final result = diffFileHashes(local, remote);
      expect(result.length, equals(1));
      expect(result.first.filePath, equals("b"));
    });

    test("extra file in local not in remote is not returned", () {
      const local = [
        FileHash(filePath: "a", hash: "x", length: 1),
        FileHash(filePath: "extra", hash: "z", length: 3),
      ];
      const remote = [FileHash(filePath: "a", hash: "x", length: 1)];
      final result = diffFileHashes(local, remote);
      expect(result, isEmpty);
    });
  });

  group("generateLocalFileHashes", () {
    late Directory tempRoot;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync("file_hasher_test_");
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test("non-existent path throws NoPlatformEntry", () async {
      final fakePath =
          "${tempRoot.path}/nonexistent/Contents/MacOS/fake_executable";
      expect(
        () => generateLocalFileHashes(path: fakePath),
        throwsA(isA<NoPlatformEntry>()),
      );
    });

    test(
      "path pointing to temp directory with one file returns List<FileHash> with length 1",
      () async {
        // On macOS the function calls dir.parent, so we need:
        // tempRoot/Contents/MacOS/fake_executable → dir = MacOS/, dir.parent = Contents/
        // Place test file at tempRoot/Contents/test.txt
        Directory("${tempRoot.path}/Contents").createSync();
        final macosDir = Directory("${tempRoot.path}/Contents/MacOS")
          ..createSync();
        File("${tempRoot.path}/Contents/test.txt")
            .writeAsBytesSync([1, 2, 3, 4, 5]);
        final overridePath = "${macosDir.path}/fake_executable";

        final result = await generateLocalFileHashes(path: overridePath);

        expect(result.length, equals(1));
        expect(result.first.filePath, equals("test.txt"));
        expect(result.first.length, equals(5));
        expect(result.first.hash, isNotEmpty);
      },
    );

    test("empty directory returns empty list", () async {
      // On macOS: tempRoot/Contents/MacOS/fake_executable → parent = tempRoot/Contents/
      // Contents/ dir exists but has no files (only the MacOS subdirectory).
      Directory("${tempRoot.path}/Contents").createSync();
      final macosDir = Directory("${tempRoot.path}/Contents/MacOS")
        ..createSync();
      final overridePath = "${macosDir.path}/fake_executable";

      final result = await generateLocalFileHashes(path: overridePath);

      expect(result, isEmpty);
    });
  });
}
