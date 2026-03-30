import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:macos_updater/macos_updater_platform_interface.dart';

/// An implementation of [MacosUpdaterPlatform] that uses method channels.
class MethodChannelMacosUpdater extends MacosUpdaterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('macos_updater');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<void> restartApp() async {
    await methodChannel.invokeMethod<void>('restartApp');
  }

  @override
  Future<String?> sayHello() async {
    return methodChannel.invokeMethod<String>('sayHello');
  }

  @override
  Future<String?> getExecutablePath() async {
    return methodChannel.invokeMethod<String>('getExecutablePath');
  }

  @override
  Future<String> getCurrentVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getCurrentVersion');
    return version!;
  }
}
