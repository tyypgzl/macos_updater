import "package:desktop_updater_example/app.dart";
import "package:flutter/material.dart";

void main() {
  runApp(const MyApp());
}

/// Example app demonstrating the desktop_updater plugin.
class MyApp extends StatefulWidget {
  /// Creates the example app.
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: HomePage(),
    );
  }
}
