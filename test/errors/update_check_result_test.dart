import "package:macos_updater/src/errors/update_check_result.dart";
import "package:macos_updater/src/models/file_hash.dart";
import "package:macos_updater/src/models/update_info.dart";
import "package:flutter_test/flutter_test.dart";

// Helper function that exercises an exhaustive switch over all 3 variants.
// This will fail to compile if any variant is missing or if a default is needed.
String describeResult(UpdateCheckResult result) {
  return switch (result) {
    UpToDate() => "up-to-date",
    ForceUpdateRequired(:final info) => "force:${info.version}",
    OptionalUpdateAvailable(:final info) => "optional:${info.version}",
  };
}

UpdateInfo _makeInfo(String version) => UpdateInfo(
  version: version,
  buildNumber: 100,
  remoteBaseUrl: "https://example.com",
  changedFiles: const [FileHash(filePath: "a", hash: "h", length: 1)],
);

void main() {
  group("UpdateCheckResult — three-way sealed", () {
    test("UpToDate is a UpdateCheckResult", () {
      const result = UpToDate();
      expect(result, isA<UpdateCheckResult>());
    });

    test("ForceUpdateRequired carries info field correctly", () {
      final info = _makeInfo("1.0.0");
      final result = ForceUpdateRequired(info);
      expect(result, isA<UpdateCheckResult>());
      expect(result.info.version, equals("1.0.0"));
      expect(result.info.buildNumber, equals(100));
    });

    test("OptionalUpdateAvailable carries info field correctly", () {
      final info = _makeInfo("2.0.0");
      final result = OptionalUpdateAvailable(info);
      expect(result, isA<UpdateCheckResult>());
      expect(result.info.version, equals("2.0.0"));
    });

    test("exhaustive switch compiles and returns correct strings", () {
      expect(describeResult(const UpToDate()), equals("up-to-date"));
      expect(
        describeResult(ForceUpdateRequired(_makeInfo("1.0.0"))),
        equals("force:1.0.0"),
      );
      expect(
        describeResult(OptionalUpdateAvailable(_makeInfo("2.0.0"))),
        equals("optional:2.0.0"),
      );
    });
  });
}
