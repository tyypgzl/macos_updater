import "package:macos_updater/src/models/platform_update_details.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("PlatformUpdateDetails", () {
    test("minimum field is set correctly", () {
      const details = PlatformUpdateDetails(
        minimum: "1.0.1",
        latest: "1.0.2",
        active: true,
      );
      expect(details.minimum, equals("1.0.1"));
    });

    test("latest field is set correctly", () {
      const details = PlatformUpdateDetails(
        minimum: "1.0.1",
        latest: "1.0.2",
        active: true,
      );
      expect(details.latest, equals("1.0.2"));
    });

    test("active field is set correctly", () {
      const details = PlatformUpdateDetails(
        minimum: "1.0.1",
        latest: "1.0.2",
        active: true,
      );
      expect(details.active, isTrue);
    });

    test("copyWith with no args returns equal instance", () {
      const original = PlatformUpdateDetails(
        minimum: "1.0.1",
        latest: "1.0.2",
        active: true,
      );
      final copy = original.copyWith();
      expect(copy.minimum, original.minimum);
      expect(copy.latest, original.latest);
      expect(copy.active, original.active);
    });

    test("copyWith(active: false) overrides only active", () {
      const original = PlatformUpdateDetails(
        minimum: "1.0.1",
        latest: "1.0.2",
        active: true,
      );
      final copy = original.copyWith(active: false);
      expect(copy.minimum, "1.0.1");
      expect(copy.latest, "1.0.2");
      expect(copy.active, isFalse);
    });
  });
}
