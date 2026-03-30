import "package:macos_updater/src/models/platform_update_details.dart";
import "package:macos_updater/src/models/update_details.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("UpdateDetails", () {
    test("macos is null when not provided", () {
      const details = UpdateDetails(macos: null);
      expect(details.macos, isNull);
    });

    test("remoteBaseUrl is null when not provided", () {
      const details = UpdateDetails(macos: null);
      expect(details.remoteBaseUrl, isNull);
    });

    test("macos is non-null when provided", () {
      const platform = PlatformUpdateDetails(
        minimum: "1.0.0",
        latest: "1.0.1",
        active: true,
      );
      const details = UpdateDetails(
        macos: platform,
        remoteBaseUrl: "https://example.com",
      );
      expect(details.macos, isNotNull);
    });

    test("remoteBaseUrl is set when provided", () {
      const platform = PlatformUpdateDetails(
        minimum: "1.0.0",
        latest: "1.0.1",
        active: true,
      );
      const details = UpdateDetails(
        macos: platform,
        remoteBaseUrl: "https://example.com",
      );
      expect(details.remoteBaseUrl, equals("https://example.com"));
    });

    test("copyWith with no args returns equal instance", () {
      const platform = PlatformUpdateDetails(
        minimum: "1.0.0",
        latest: "1.0.1",
        active: true,
      );
      const original = UpdateDetails(
        macos: platform,
        remoteBaseUrl: "https://example.com",
      );
      final copy = original.copyWith();
      expect(copy.macos, original.macos);
      expect(copy.remoteBaseUrl, original.remoteBaseUrl);
    });

    test("copyWith(remoteBaseUrl: null) clears the field", () {
      const platform = PlatformUpdateDetails(
        minimum: "1.0.0",
        latest: "1.0.1",
        active: true,
      );
      const original = UpdateDetails(
        macos: platform,
        remoteBaseUrl: "https://example.com",
      );
      final copy = original.copyWith(remoteBaseUrl: null);
      expect(copy.remoteBaseUrl, isNull);
      expect(copy.macos?.minimum, equals("1.0.0"));
    });
  });
}
