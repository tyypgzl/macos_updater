import "package:macos_updater/macos_updater_method_channel.dart";
import "package:macos_updater/macos_updater_platform_interface.dart";
import "package:flutter_test/flutter_test.dart";
import "package:plugin_platform_interface/plugin_platform_interface.dart";

class MockMacosUpdaterPlatform
    extends MacosUpdaterPlatform
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
  Future<String> getCurrentVersion() {
    return Future.value('1.0.0');
  }
}

void main() {
  final initialPlatform = MacosUpdaterPlatform.instance;

  test("$MethodChannelMacosUpdater is the default instance", () {
    expect(initialPlatform, isInstanceOf<MethodChannelMacosUpdater>());
  });

  test("getPlatformVersion", () async {
    final fakePlatform = MockMacosUpdaterPlatform();
    MacosUpdaterPlatform.instance = fakePlatform;

    expect(await MacosUpdaterPlatform.instance.getPlatformVersion(), "42");
  });
}
