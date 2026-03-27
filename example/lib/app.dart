import "package:desktop_updater/desktop_updater.dart";
import "package:flutter/material.dart";

/// Example home page demonstrating the v2 desktop_updater API.
///
/// In a real app, implement [UpdateSource] and call [checkForUpdate],
/// [downloadUpdate], and [applyUpdate] from your own UI layer.
class HomePage extends StatelessWidget {
  /// Creates a [HomePage].
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("desktop_updater v2 example"),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "desktop_updater v2",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                "Implement UpdateSource and call:\n"
                "  checkForUpdate(source)\n"
                "  downloadUpdate(info, onProgress: ...)\n"
                "  applyUpdate()",
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
