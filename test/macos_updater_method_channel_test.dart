import 'package:macos_updater/macos_updater_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelMacosUpdater();
  const channel = MethodChannel('macos_updater');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getPlatformVersion':
            return '42';
          case 'getCurrentVersion':
            return '1.2.3';
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion returns the mocked string', () async {
    expect(await platform.getPlatformVersion(), '42');
  });

  test('getCurrentVersion returns a String semver value', () async {
    final version = await platform.getCurrentVersion();
    expect(version, isA<String>());
    expect(version, '1.2.3');
  });
}
