# Testing Patterns

**Analysis Date:** 2026-03-26

## Test Framework

**Runner:**
- `flutter_test` (built into Flutter SDK)
- No configuration file required (uses defaults)

**Assertion Library:**
- Dart's built-in `expect()` function from `flutter_test`
- Matcher syntax: `expect(value, matcher)`

**Run Commands:**
```bash
flutter test                          # Run all tests
flutter test --watch               # Watch mode (rerun on file changes)
flutter test --coverage            # Generate coverage report
flutter test test/desktop_updater_test.dart  # Run single test file
```

## Test File Organization

**Location:**
- Tests are co-located in `test/` directory at root level
- Each main library file has corresponding test file
- Current test files: `test/desktop_updater_test.dart`, `test/desktop_updater_method_channel_test.dart`

**Naming:**
- Suffix `_test.dart` for test files
- Pattern: `{subject}_test.dart`
- Examples: `desktop_updater_test.dart`, `desktop_updater_method_channel_test.dart`

**Structure:**
```
test/
├── desktop_updater_test.dart
└── desktop_updater_method_channel_test.dart
```

## Test Structure

**Suite Organization:**
```dart
import "package:desktop_updater/desktop_updater.dart";
import "package:desktop_updater/desktop_updater_method_channel.dart";
import "package:desktop_updater/desktop_updater_platform_interface.dart";
import "package:flutter_test/flutter_test.dart";
import "package:plugin_platform_interface/plugin_platform_interface.dart";

void main() {
  final initialPlatform = DesktopUpdaterPlatform.instance;

  test("$MethodChannelDesktopUpdater is the default instance", () {
    expect(initialPlatform, isInstanceOf<MethodChannelDesktopUpdater>());
  });

  test("getPlatformVersion", () async {
    final desktopUpdaterPlugin = DesktopUpdater();
    final fakePlatform = MockDesktopUpdaterPlatform();
    DesktopUpdaterPlatform.instance = fakePlatform;

    expect(await desktopUpdaterPlugin.getPlatformVersion(), "42");
  });
}
```

**Patterns:**
- Single `void main()` entry point per test file
- Top-level test setup before test definitions
- Individual `test()` blocks for each test case
- Async tests use `async` keyword: `test("name", () async { })`

## Mocking

**Framework:** Manual mocking (no mocking library like mockito)

**Patterns:**
```dart
class MockDesktopUpdaterPlatform
    with MockPlatformInterfaceMixin
    implements DesktopUpdaterPlatform {
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
  Future<List<FileHashModel?>> verifyFileHash(
    String oldHashFilePath,
    String newHashFilePath,
  ) {
    return Future.value([]);
  }

  @override
  Future<List<FileHashModel?>> prepareUpdateApp(
      {required String remoteUpdateFolder}) {
    return Future.value([]);
  }
}
```

**What to Mock:**
- Platform-specific implementations (native method channels)
- External dependencies (HTTP requests, file system operations)
- Platform-interface classes that define contracts

**What NOT to Mock:**
- Data models and immutable value objects
- Pure utility functions
- Business logic functions (test them directly)

## Fixtures and Factories

**Test Data:**
- No explicit fixture files used
- Hardcoded test values in tests: `"42"` for version, `[]` for empty lists
- Test data created inline within test blocks

**Location:**
- Test setup code at top of test file
- Mocks created inline within test blocks
- No separate fixture factory classes

**Example Setup from `test/desktop_updater_method_channel_test.dart`:**
```dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelDesktopUpdater platform = MethodChannelDesktopUpdater();
  const MethodChannel channel = MethodChannel('desktop_updater');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });
}
```

## Coverage

**Requirements:** Not enforced (no coverage goals specified in configuration)

**View Coverage:**
```bash
flutter test --coverage                    # Generate coverage/lcov.info
# Coverage data written to coverage/lcov.info
```

## Test Types

**Unit Tests:**
- Focus on individual functions and classes in isolation
- Test platform interface implementations
- Example: `test("$MethodChannelDesktopUpdater is the default instance", ...)`
- Examples: `test("getPlatformVersion", ...)`
- Scope: Single public method or function behavior

**Integration Tests:**
- Not currently present in codebase
- Would test interaction between multiple components
- Would require actual file I/O and HTTP calls

**E2E Tests:**
- Not detected/not used
- Would require flutter_test with actual app widget testing

**Widget Tests:**
- Limited widget testing (none currently implemented for UI components)
- Would test Flutter widget rendering and interaction
- Would use `testWidgets()` instead of `test()`
- Would require `WidgetTester` parameter

## Current Test Coverage

**Tested Areas:**
- `lib/desktop_updater.dart` - Basic functionality via `desktop_updater_test.dart`
- `lib/desktop_updater_method_channel.dart` - Platform channel via `desktop_updater_method_channel_test.dart`
- `lib/desktop_updater_platform_interface.dart` - Platform interface contract

**Untested Areas (Priority Gaps):**
- **High Priority:**
  - `lib/src/file_hash.dart` - Core hash verification logic not tested
  - `lib/src/version_check.dart` - Version checking logic not tested
  - `lib/src/download.dart` - File download logic not tested
  - `lib/src/update.dart` - Main update flow not tested
  - `lib/src/app_archive.dart` - Model serialization/deserialization not tested
  - `lib/updater_controller.dart` - ChangeNotifier state management not tested

- **Medium Priority:**
  - `lib/widget/` - No widget tests for UI components
  - `lib/widget/update_dialog.dart` - Dialog rendering and interactions
  - `lib/widget/update_card.dart` - Card rendering and interactions

- **Low Priority:**
  - `lib/src/prepare.dart` - Prepare update preparation logic
  - `lib/src/localization.dart` - String localization

## Common Patterns

**Async Testing:**
```dart
test("getPlatformVersion", () async {
  final desktopUpdaterPlugin = DesktopUpdater();
  final fakePlatform = MockDesktopUpdaterPlatform();
  DesktopUpdaterPlatform.instance = fakePlatform;

  expect(await desktopUpdaterPlugin.getPlatformVersion(), "42");
});
```

**Method Channel Testing:**
```dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelDesktopUpdater platform = MethodChannelDesktopUpdater();
  const MethodChannel channel = MethodChannel('desktop_updater');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
```

**Platform Substitution Pattern:**
```dart
final initialPlatform = DesktopUpdaterPlatform.instance;

// Test with mock
final fakePlatform = MockDesktopUpdaterPlatform();
DesktopUpdaterPlatform.instance = fakePlatform;

// Run test
expect(await desktopUpdaterPlugin.getPlatformVersion(), "42");
```

**Type Verification:**
```dart
test("$MethodChannelDesktopUpdater is the default instance", () {
  expect(initialPlatform, isInstanceOf<MethodChannelDesktopUpdater>());
});
```

## Testing Best Practices (Current State)

**Strengths:**
- Mocks properly implement `MockPlatformInterfaceMixin` for platform testing
- Async/await properly used in tests
- Clear one-assertion-per-test pattern

**Areas for Improvement:**
- Limited test coverage (only 2 test files, ~5 test cases)
- No widget tests for UI components
- No integration tests for file operations
- No mocking library (mockito) - consider for complex mocks
- Missing tests for error scenarios and edge cases
- No fixtures or test data builders for complex objects

---

*Testing analysis: 2026-03-26*
