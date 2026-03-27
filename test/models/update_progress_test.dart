import "package:macos_updater/src/models/update_progress.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("UpdateProgress", () {
    const baseProgress = UpdateProgress(
      totalBytes: 1024,
      receivedBytes: 512,
      currentFile: "Contents/MacOS/MyApp",
      totalFiles: 10,
      completedFiles: 5,
    );

    test("has all 5 required fields with correct types", () {
      expect(baseProgress.totalBytes, isA<double>());
      expect(baseProgress.receivedBytes, isA<double>());
      expect(baseProgress.currentFile, isA<String>());
      expect(baseProgress.totalFiles, isA<int>());
      expect(baseProgress.completedFiles, isA<int>());
    });

    test("copyWith with no arguments returns instance with identical fields", () {
      final copied = baseProgress.copyWith();
      expect(copied.totalBytes, equals(baseProgress.totalBytes));
      expect(copied.receivedBytes, equals(baseProgress.receivedBytes));
      expect(copied.currentFile, equals(baseProgress.currentFile));
      expect(copied.totalFiles, equals(baseProgress.totalFiles));
      expect(copied.completedFiles, equals(baseProgress.completedFiles));
    });

    test("copyWith overrides only totalBytes", () {
      final copied = baseProgress.copyWith(totalBytes: 2048);
      expect(copied.totalBytes, equals(2048));
      expect(copied.receivedBytes, equals(baseProgress.receivedBytes));
      expect(copied.currentFile, equals(baseProgress.currentFile));
      expect(copied.totalFiles, equals(baseProgress.totalFiles));
      expect(copied.completedFiles, equals(baseProgress.completedFiles));
    });

    test("copyWith overrides only receivedBytes", () {
      final copied = baseProgress.copyWith(receivedBytes: 256);
      expect(copied.totalBytes, equals(baseProgress.totalBytes));
      expect(copied.receivedBytes, equals(256));
    });

    test("copyWith overrides only completedFiles", () {
      final copied = baseProgress.copyWith(completedFiles: 7);
      expect(copied.completedFiles, equals(7));
      expect(copied.totalFiles, equals(baseProgress.totalFiles));
    });

    test("constructor is const - allows compile-time constants", () {
      const progress = UpdateProgress(
        totalBytes: 0,
        receivedBytes: 0,
        currentFile: "",
        totalFiles: 0,
        completedFiles: 0,
      );
      expect(progress.totalFiles, equals(0));
    });
  });
}
