import 'package:desktop_updater_example/app.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

/// Example app demonstrating the desktop_updater plugin.
class MyApp extends StatelessWidget {
  /// Creates the example app.
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: UpdateExamplePage(),
    );
  }
}
