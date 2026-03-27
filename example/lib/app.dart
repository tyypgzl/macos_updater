import 'dart:convert';

import 'package:desktop_updater/desktop_updater.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ─── UpdateSource Implementation ────────────────────

/// Example UpdateSource that fetches version info
/// and file hashes from a static JSON server.
///
/// Replace the URLs with your own server.
class JsonUpdateSource implements UpdateSource {
  /// Creates a [JsonUpdateSource] with the given
  /// [appArchiveUrl].
  const JsonUpdateSource({required this.appArchiveUrl});

  /// URL to the app-archive JSON file.
  final String appArchiveUrl;

  @override
  Future<UpdateInfo?> getLatestUpdateInfo() async {
    final response = await http.get(
      Uri.parse(appArchiveUrl),
    );
    if (response.statusCode != 200) return null;

    final json =
        jsonDecode(response.body) as Map<String, dynamic>;
    final items = json['items'] as List<dynamic>;

    // Find the macOS entry with the highest
    // shortVersion
    final macEntries = items
        .cast<Map<String, dynamic>>()
        .where((e) => e['platform'] == 'macos');
    if (macEntries.isEmpty) return null;

    final latest = macEntries.reduce(
      (a, b) =>
          (a['shortVersion'] as int) >
                  (b['shortVersion'] as int)
              ? a
              : b,
    );

    return UpdateInfo(
      version: latest['version'] as String,
      buildNumber: latest['shortVersion'] as int,
      remoteBaseUrl: latest['url'] as String,
      changedFiles: const [],
    );
  }

  @override
  Future<List<FileHash>> getRemoteFileHashes(
    String remoteBaseUrl,
  ) async {
    final response = await http.get(
      Uri.parse('$remoteBaseUrl/hashes.json'),
    );
    final list =
        jsonDecode(response.body) as List<dynamic>;
    return list
        .map(
          (e) => FileHash.fromJson(
            e as Map<String, dynamic>,
          ),
        )
        .toList();
  }
}

// ─── Example Page ───────────────────────────────────

/// Example page showing the full update lifecycle.
class UpdateExamplePage extends StatefulWidget {
  /// Creates an [UpdateExamplePage].
  const UpdateExamplePage({super.key});

  @override
  State<UpdateExamplePage> createState() =>
      _UpdateExamplePageState();
}

class _UpdateExamplePageState
    extends State<UpdateExamplePage> {
  final _source = const JsonUpdateSource(
    appArchiveUrl:
        'https://example.com/app-archive.json',
  );

  String _status = 'Tap "Check" to start.';
  double _progress = 0;
  UpdateInfo? _updateInfo;

  Future<void> _checkForUpdate() async {
    setState(() => _status = 'Checking...');
    try {
      final result = await checkForUpdate(_source);
      switch (result) {
        case UpToDate():
          setState(() => _status = 'Up to date!');
        case UpdateAvailable(:final info):
          setState(() {
            _updateInfo = info;
            _status = 'Update available: '
                '${info.version} '
                '(${info.changedFiles.length} files)';
          });
      }
    } on UpdateError catch (e) {
      setState(() => _status = 'Error: ${e.message}');
    }
  }

  Future<void> _download() async {
    final info = _updateInfo;
    if (info == null) return;

    setState(() => _status = 'Downloading...');
    try {
      await downloadUpdate(
        info,
        onProgress: (p) {
          setState(() {
            _progress = p.totalBytes > 0
                ? p.receivedBytes / p.totalBytes
                : 0;
            _status = 'Downloading '
                '${p.completedFiles}/${p.totalFiles}';
          });
        },
      );
      setState(() {
        _status = 'Download complete! Tap "Apply".';
        _progress = 1;
      });
    } on UpdateError catch (e) {
      setState(
        () => _status = 'Download error: ${e.message}',
      );
    }
  }

  Future<void> _apply() async {
    setState(() => _status = 'Restarting...');
    try {
      await applyUpdate();
    } on RestartFailed catch (e) {
      setState(
        () => _status = 'Restart failed: ${e.message}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('desktop_updater example'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _status,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium,
              ),
              const SizedBox(height: 16),
              if (_progress > 0 && _progress < 1)
                LinearProgressIndicator(
                  value: _progress,
                ),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: _checkForUpdate,
                    child: const Text('Check'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed:
                        _updateInfo != null
                            ? _download
                            : null,
                    child: const Text('Download'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed:
                        _progress >= 1 ? _apply : null,
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
