import 'package:desktop_updater_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Example app renders', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Check'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
    expect(
      find.byType(ElevatedButton),
      findsNWidgets(3),
    );
  });
}
