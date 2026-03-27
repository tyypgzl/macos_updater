import 'package:macos_updater/macos_updater.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'getCurrentVersion returns an int',
    (tester) async {
      final version = await MacosUpdaterPlatform
          .instance
          .getCurrentVersion();
      expect(version, isA<int>());
    },
  );
}
