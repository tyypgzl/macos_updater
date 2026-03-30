import 'package:macos_updater/src/models/file_hash.dart';
import 'package:macos_updater/src/models/update_info.dart';
import 'package:macos_updater/src/models/update_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FileHash', () {
    test('copyWith with no arguments returns equal instance', () {
      const original = FileHash(
        filePath: 'Contents/MacOS/MyApp',
        hash: 'abc123def456',
        length: 2048,
      );
      final copy = original.copyWith();
      expect(copy.filePath, original.filePath);
      expect(copy.hash, original.hash);
      expect(copy.length, original.length);
    });

    test('copyWith overrides only specified field', () {
      const original = FileHash(
        filePath: 'Contents/MacOS/MyApp',
        hash: 'abc123def456',
        length: 2048,
      );
      final copy = original.copyWith(hash: 'newHash999');
      expect(copy.filePath, 'Contents/MacOS/MyApp');
      expect(copy.hash, 'newHash999');
      expect(copy.length, 2048);
    });

    test('fromJson round-trip preserves all fields', () {
      const original = FileHash(
        filePath: 'Contents/Frameworks/libflutter.dylib',
        hash: 'deadbeef',
        length: 99999,
      );
      final decoded = FileHash.fromJson(original.toJson());
      expect(decoded.filePath, original.filePath);
      expect(decoded.hash, original.hash);
      expect(decoded.length, original.length);
    });

    test('fromJson reads correct JSON keys', () {
      final fh = FileHash.fromJson(const {
        'path': 'Contents/MacOS/Runner',
        'calculatedHash': 'sha256abc',
        'length': 512,
      });
      expect(fh.filePath, 'Contents/MacOS/Runner');
      expect(fh.hash, 'sha256abc');
      expect(fh.length, 512);
    });

    test('toJson writes correct JSON keys', () {
      const fh = FileHash(filePath: 'a/b/c', hash: 'h1', length: 10);
      final json = fh.toJson();
      expect(json['path'], 'a/b/c');
      expect(json['calculatedHash'], 'h1');
      expect(json['length'], 10);
      expect(json.containsKey('filePath'), isFalse);
      expect(json.containsKey('hash'), isFalse);
    });
  });

  group('UpdateInfo', () {
    test('copyWith with no arguments returns equal instance', () {
      const file = FileHash(filePath: 'a', hash: 'h', length: 1);
      const original = UpdateInfo(
        version: '2.0.0',
        remoteBaseUrl: 'https://example.com/updates',
        changedFiles: [file],
      );
      final copy = original.copyWith();
      expect(copy.version, original.version);
      expect(copy.remoteBaseUrl, original.remoteBaseUrl);
      expect(copy.changedFiles, original.changedFiles);
    });

    test('copyWith overrides only specified field', () {
      const file = FileHash(filePath: 'a', hash: 'h', length: 1);
      const original = UpdateInfo(
        version: '2.0.0',
        remoteBaseUrl: 'https://example.com/updates',
        changedFiles: [file],
      );
      final copy = original.copyWith(version: '2.1.0');
      expect(copy.version, '2.1.0');
      expect(copy.remoteBaseUrl, 'https://example.com/updates');
      expect(copy.changedFiles, [file]);
    });
  });

  group('UpdateInfo — new fields', () {
    test(
      'constructed with 3 required fields has minimumVersion=null, releaseNotes=null',
      () {
        const info = UpdateInfo(
          version: '1.0.0',
          remoteBaseUrl: 'https://example.com',
          changedFiles: [],
        );
        expect(info.minimumVersion, isNull);
        expect(info.releaseNotes, isNull);
      },
    );

    test(
      'constructed with minimumVersion and releaseNotes preserves both',
      () {
        const info = UpdateInfo(
          version: '1.0.0',
          remoteBaseUrl: 'https://example.com',
          changedFiles: [],
          minimumVersion: '2.0.0',
          releaseNotes: 'Bug fixes',
        );
        expect(info.minimumVersion, equals('2.0.0'));
        expect(info.releaseNotes, equals('Bug fixes'));
      },
    );

    test('copyWith with no arguments returns instance with same 5 fields', () {
      const info = UpdateInfo(
        version: '2.0.0',
        remoteBaseUrl: 'https://example.com',
        changedFiles: [],
        minimumVersion: '1.5.0',
        releaseNotes: 'v2',
      );
      final copy = info.copyWith();
      expect(copy.version, info.version);
      expect(copy.remoteBaseUrl, info.remoteBaseUrl);
      expect(copy.changedFiles, info.changedFiles);
      expect(copy.minimumVersion, info.minimumVersion);
      expect(copy.releaseNotes, info.releaseNotes);
    });

    test(
      'copyWith(minimumVersion: "2.0.0") overrides only minimumVersion',
      () {
        const info = UpdateInfo(
          version: '2.0.0',
          remoteBaseUrl: 'https://example.com',
          changedFiles: [],
        );
        final copy = info.copyWith(minimumVersion: '2.0.0');
        expect(copy.minimumVersion, '2.0.0');
        expect(copy.version, '2.0.0');
        expect(copy.remoteBaseUrl, 'https://example.com');
        expect(copy.changedFiles, isEmpty);
        expect(copy.releaseNotes, isNull);
      },
    );

    test(
      'copyWith(minimumVersion: null) clears minimumVersion via sentinel',
      () {
        const info = UpdateInfo(
          version: '2.0.0',
          remoteBaseUrl: 'https://example.com',
          changedFiles: [],
          minimumVersion: '1.5.0',
        );
        final copy = info.copyWith(minimumVersion: null);
        expect(copy.minimumVersion, isNull);
        expect(copy.version, '2.0.0');
      },
    );

    test(
      'copyWith(releaseNotes: null) clears releaseNotes via sentinel',
      () {
        const info = UpdateInfo(
          version: '2.0.0',
          remoteBaseUrl: 'https://example.com',
          changedFiles: [],
          releaseNotes: 'v2',
        );
        final copy = info.copyWith(releaseNotes: null);
        expect(copy.releaseNotes, isNull);
        expect(copy.version, '2.0.0');
      },
    );

    test(
      'copyWith(minimumVersion: "2.0.0", releaseNotes: "v2") overrides only those two',
      () {
        const info = UpdateInfo(
          version: '1.0.0',
          remoteBaseUrl: 'https://example.com',
          changedFiles: [],
        );
        final copy = info.copyWith(
          minimumVersion: '2.0.0',
          releaseNotes: 'v2',
        );
        expect(copy.minimumVersion, equals('2.0.0'));
        expect(copy.releaseNotes, equals('v2'));
        expect(copy.version, '1.0.0');
      },
    );
  });

  group('UpdateProgress', () {
    test('copyWith with no arguments returns equal instance', () {
      const original = UpdateProgress(
        totalBytes: 1000,
        receivedBytes: 500,
        currentFile: 'libflutter.dylib',
        totalFiles: 3,
        completedFiles: 1,
      );
      final copy = original.copyWith();
      expect(copy.totalBytes, original.totalBytes);
      expect(copy.receivedBytes, original.receivedBytes);
      expect(copy.currentFile, original.currentFile);
      expect(copy.totalFiles, original.totalFiles);
      expect(copy.completedFiles, original.completedFiles);
    });

    test('copyWith overrides only specified field', () {
      const original = UpdateProgress(
        totalBytes: 1000,
        receivedBytes: 500,
        currentFile: 'libflutter.dylib',
        totalFiles: 3,
        completedFiles: 1,
      );
      final copy = original.copyWith(completedFiles: 2, receivedBytes: 750);
      expect(copy.totalBytes, 1000);
      expect(copy.receivedBytes, 750);
      expect(copy.currentFile, 'libflutter.dylib');
      expect(copy.totalFiles, 3);
      expect(copy.completedFiles, 2);
    });
  });
}
