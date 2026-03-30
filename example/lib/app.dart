import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:macos_updater/macos_updater.dart';

// ─── UpdateSource Implementation ────────────────────

/// Example UpdateSource that fetches version info
/// and file hashes from a static JSON server.
///
/// Replace the URLs with your own server.
class JsonUpdateSource implements UpdateSource {
  /// Creates a [JsonUpdateSource] with the given
  /// [updateDetailsUrl] and [remoteBaseUrl].
  const JsonUpdateSource({
    required this.updateDetailsUrl,
    required this.remoteBaseUrl,
  });

  /// URL to the update details JSON file.
  final String updateDetailsUrl;

  /// Base URL where update files are hosted.
  final String remoteBaseUrl;

  @override
  Future<UpdateDetails?> getUpdateDetails() async {
    final response = await http.get(
      Uri.parse(updateDetailsUrl),
    );
    if (response.statusCode != 200) return null;

    final json =
        jsonDecode(response.body) as Map<String, dynamic>;
    final macosJson =
        json['macos'] as Map<String, dynamic>?;
    if (macosJson == null) return null;

    return UpdateDetails(
      macos: PlatformUpdateDetails(
        minimum: macosJson['minimum'] as String,
        latest: macosJson['latest'] as String,
        active: macosJson['active'] as bool,
      ),
      remoteBaseUrl: remoteBaseUrl,
    );
  }

  @override
  Future<List<FileHash>> getRemoteFileHashes(
    String baseUrl,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/hashes.json'),
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
    updateDetailsUrl:
        'https://example.com/update-details.json',
    remoteBaseUrl: 'https://example.com/updates',
  );

  String _status = 'Tap "Check" to start.';
  double _progress = 0;
  UpdateInfo? _updateInfo;

  /// Whether the pending update requires a forced install (cannot be skipped).
  bool _isForceRequired = false;

  Future<void> _checkForUpdate() async {
    setState(() => _status = 'Checking...');
    try {
      final result = await checkForUpdate(_source);
      switch (result) {
        case UpToDate():
          setState(() => _status = 'Up to date!');
        case ForceUpdateRequired(:final info):
          setState(() {
            _updateInfo = info;
            _isForceRequired = true;
            _status =
                'REQUIRED update: ${info.version} — must install';
          });
        case OptionalUpdateAvailable(:final info):
          setState(() {
            _updateInfo = info;
            _isForceRequired = false;
            _status =
                'Update available: ${info.version} '
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
        title: const Text('macos_updater example'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isForceRequired && _updateInfo != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.shade100,
                    border: Border.all(
                      color: Colors.deepOrange,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Update required — you must install this '
                    'update to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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
