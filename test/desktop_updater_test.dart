import "package:desktop_updater/desktop_updater_method_channel.dart";
import "package:desktop_updater/desktop_updater_platform_interface.dart";
import "package:flutter_test/flutter_test.dart";
import "package:plugin_platform_interface/plugin_platform_interface.dart";

class MockDesktopUpdaterPlatform
    extends DesktopUpdaterPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getPlatformVersion() => Future.value("42");

  @override
  Future<void> restartApp() {
    return Future.value();
  }

  @override
  Future<String?> sayHello() {
    return Future.value();
  }

  @override
  Future<String?> getExecutablePath() {
    return Future.value();
  }

  @override
  Future<int> getCurrentVersion() {
    return Future.value(42);
  }
}

void main() {
  final initialPlatform = DesktopUpdaterPlatform.instance;

  test("$MethodChannelDesktopUpdater is the default instance", () {
    expect(initialPlatform, isInstanceOf<MethodChannelDesktopUpdater>());
  });

  test("getPlatformVersion", () async {
    final fakePlatform = MockDesktopUpdaterPlatform();
    DesktopUpdaterPlatform.instance = fakePlatform;

    expect(await DesktopUpdaterPlatform.instance.getPlatformVersion(), "42");
  });
}
