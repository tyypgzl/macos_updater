import 'package:desktop_updater/desktop_updater_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Abstract platform interface for the desktop_updater plugin.
///
/// Platform implementations must extend this class and register themselves
/// as the [instance] before any API calls are made.
abstract class DesktopUpdaterPlatform extends PlatformInterface {
  /// Constructs a DesktopUpdaterPlatform.
  DesktopUpdaterPlatform() : super(token: _token);

  static final Object _token = Object();

  static DesktopUpdaterPlatform _instance = MethodChannelDesktopUpdater();

  /// The default instance of [DesktopUpdaterPlatform] to use.
  ///
  /// Defaults to [MethodChannelDesktopUpdater].
  static DesktopUpdaterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [DesktopUpdaterPlatform] when
  /// they register themselves.
  static set instance(DesktopUpdaterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Returns the platform version string (e.g. "macOS 14.0").
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Restarts the application to apply a downloaded update.
  Future<void> restartApp() {
    throw UnimplementedError('restartApp() has not been implemented.');
  }

  /// Returns a hello string from the native layer (for testing).
  Future<String?> sayHello() {
    throw UnimplementedError('sayHello() has not been implemented.');
  }

  /// Returns the resolved executable path.
  Future<String?> getExecutablePath() {
    throw UnimplementedError('getExecutablePath() has not been implemented.');
  }

  /// Returns the current app build number (CFBundleVersion on macOS).
  Future<int> getCurrentVersion() {
    throw UnimplementedError('getCurrentVersion() has not been implemented.');
  }
}
