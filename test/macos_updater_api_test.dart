import 'dart:io';

import 'package:macos_updater/macos_updater_platform_interface.dart';
import 'package:macos_updater/src/errors/update_check_result.dart';
import 'package:macos_updater/src/errors/update_error.dart';
import 'package:macos_updater/src/macos_updater_api.dart';
import 'package:macos_updater/src/models/file_hash.dart';
import 'package:macos_updater/src/models/platform_update_details.dart';
import 'package:macos_updater/src/models/update_details.dart';
import 'package:macos_updater/src/models/update_info.dart';
import 'package:macos_updater/src/update_source.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// Minimal [UpdateSource] returning controlled fixtures.
class MockUpdateSource implements UpdateSource {
  MockUpdateSource({this.details, this.fileHashes = const []});

  final UpdateDetails? details;
  final List<FileHash> fileHashes;

  @override
  Future<UpdateDetails?> getUpdateDetails() async => details;

  @override
  Future<List<FileHash>> getRemoteFileHashes(String remoteBaseUrl) async =>
      fileHashes;
}

/// [UpdateSource] that always throws a plain [Exception] from getUpdateDetails.
class ThrowingUpdateSource implements UpdateSource {
  @override
  Future<UpdateDetails?> getUpdateDetails() =>
      Future.error(Exception('backend unavailable'));

  @override
  Future<List<FileHash>> getRemoteFileHashes(String remoteBaseUrl) =>
      Future.error(Exception('hash fetch failed'));
}

/// Mock platform that extends (not implements) the abstract
/// class so `PlatformInterface.verifyToken` passes when assigning to
/// `MacosUpdaterPlatform.instance`.
class MockMacosUpdaterPlatform extends MacosUpdaterPlatform {
  bool restartShouldThrow = false;
  String versionToReturn = '1.0.0';

  @override
  Future<void> restartApp() async {
    if (restartShouldThrow) {
      throw PlatformException(code: 'restart_failed');
    }
  }

  @override
  Future<String> getCurrentVersion() async => versionToReturn;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _remoteUrl = 'https://example.com/updates';

UpdateDetails _makeUpdateDetails({
  String minimum = '1.0.0',
  String latest = '2.0.0',
  bool active = true,
  String remoteBaseUrl = _remoteUrl,
}) {
  return UpdateDetails(
    macos: PlatformUpdateDetails(
      minimum: minimum,
      latest: latest,
      active: active,
    ),
    remoteBaseUrl: remoteBaseUrl,
  );
}

UpdateInfo _makeUpdateInfo({
  String version = '2.0.0',
  List<FileHash> changedFiles = const [],
  String? minimumVersion,
  String? releaseNotes,
}) {
  return UpdateInfo(
    version: version,
    remoteBaseUrl: _remoteUrl,
    changedFiles: changedFiles,
    minimumVersion: minimumVersion,
    releaseNotes: releaseNotes,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMacosUpdaterPlatform mockPlatform;

  setUp(() {
    mockPlatform = MockMacosUpdaterPlatform();
    MacosUpdaterPlatform.instance = mockPlatform;
  });

  // -------------------------------------------------------------------------
  group('checkForUpdate', () {
    test('returns UpToDate when getUpdateDetails() returns null', () async {
      final source = MockUpdateSource();
      final result = await checkForUpdate(source);
      expect(result, isA<UpToDate>());
    });

    test('returns UpToDate when macos is null', () async {
      final source = MockUpdateSource(
        details: const UpdateDetails(),
      );
      final result = await checkForUpdate(source);
      expect(result, isA<UpToDate>());
    });

    test('returns UpToDate when active is false', () async {
      final source = MockUpdateSource(
        details: _makeUpdateDetails(active: false),
      );
      final result = await checkForUpdate(source);
      expect(result, isA<UpToDate>());
    });

    test('returns UpToDate when currentVersion equals latest', () async {
      mockPlatform.versionToReturn = '2.0.0';
      final source = MockUpdateSource(
        details: _makeUpdateDetails(latest: '2.0.0'),
      );
      final result = await checkForUpdate(source);
      expect(result, isA<UpToDate>());
    });

    test('returns UpToDate when currentVersion is ahead of latest', () async {
      mockPlatform.versionToReturn = '3.0.0';
      final source = MockUpdateSource(
        details: _makeUpdateDetails(latest: '2.0.0'),
      );
      final result = await checkForUpdate(source);
      expect(result, isA<UpToDate>());
    });

    test('wraps source exception in NetworkError', () async {
      final source = ThrowingUpdateSource();
      expect(
        () => checkForUpdate(source),
        throwsA(
          isA<NetworkError>().having(
            (e) => e.cause,
            'cause',
            isA<Exception>(),
          ),
        ),
      );
    });

    group('semver enforcement', () {
      late Directory tempRoot;
      late String localHashesPath;

      setUp(() {
        // Mirror the macOS layout: tempRoot/Contents/MacOS/fake_executable
        tempRoot = Directory.systemTemp.createTempSync('check_update_test_');
        final macosDir = Directory('${tempRoot.path}/Contents/MacOS')
          ..createSync(recursive: true);
        localHashesPath = '${macosDir.path}/fake_executable';
      });

      tearDown(() {
        if (tempRoot.existsSync()) {
          tempRoot.deleteSync(recursive: true);
        }
      });

      test(
        'returns ForceUpdateRequired when currentVersion < minimum',
        () async {
          mockPlatform.versionToReturn = '0.9.0';
          final source = MockUpdateSource(
            details: _makeUpdateDetails(minimum: '1.0.0', latest: '2.0.0'),
          );
          final result = await checkForUpdate(
            source,
            localHashesPath: localHashesPath,
          );
          expect(result, isA<ForceUpdateRequired>());
        },
      );

      test(
        'returns OptionalUpdateAvailable when currentVersion >= minimum and < latest',
        () async {
          mockPlatform.versionToReturn = '1.0.5';
          final source = MockUpdateSource(
            details: _makeUpdateDetails(minimum: '1.0.0', latest: '2.0.0'),
          );
          final result = await checkForUpdate(
            source,
            localHashesPath: localHashesPath,
          );
          expect(result, isA<OptionalUpdateAvailable>());
        },
      );
    });
  });

  // -------------------------------------------------------------------------
  group('downloadUpdate', () {
    test(
      'completes without calling onProgress when changedFiles is empty',
      () async {
        var progressCallCount = 0;
        final info = _makeUpdateInfo(changedFiles: const []);

        await downloadUpdate(
          info,
          onProgress: (_) {
            progressCallCount++;
          },
        );

        expect(progressCallCount, 0);
      },
    );

    test(
      'returns a Future<void> (callable with empty changedFiles)',
      () async {
        final info = _makeUpdateInfo(changedFiles: const []);
        final result = downloadUpdate(info);
        expect(result, isA<Future<void>>());
        await result; // must complete without error
      },
    );
  });

  // -------------------------------------------------------------------------
  group('applyUpdate', () {
    test('completes normally when platform restartApp succeeds', () async {
      mockPlatform.restartShouldThrow = false;
      await expectLater(applyUpdate(), completes);
    });

    test(
      'throws RestartFailed when platform restartApp throws PlatformException',
      () async {
        mockPlatform.restartShouldThrow = true;
        expect(
          applyUpdate,
          throwsA(
            isA<RestartFailed>().having(
              (e) => e.cause,
              'cause',
              isA<PlatformException>(),
            ),
          ),
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  group('generateLocalFileHashes', () {
    late Directory tempRoot;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync('api_test_');
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test(
      'delegates to engine and returns List<FileHash> for a temp directory',
      () async {
        // Mirror the macOS layout expected by the engine:
        // tempRoot/Contents/MacOS/fake_executable → parent → Contents/
        // Place one file at tempRoot/Contents/test.txt
        Directory('${tempRoot.path}/Contents').createSync();
        final macosDir = Directory('${tempRoot.path}/Contents/MacOS')
          ..createSync();
        File('${tempRoot.path}/Contents/test.txt')
            .writeAsBytesSync([10, 20, 30]);
        final overridePath = '${macosDir.path}/fake_executable';

        final result = await generateLocalFileHashes(path: overridePath);

        expect(result, isA<List<FileHash>>());
        expect(result.length, equals(1));
        expect(result.first.filePath, equals('test.txt'));
      },
    );
  });
}
