import 'package:flutter/material.dart';
import 'package:macos_updater_example/app.dart';

void main() {
  runApp(const MyApp());
}

/// Example app demonstrating the macos_updater plugin.
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
