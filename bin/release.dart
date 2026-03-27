import "dart:convert";
import "dart:io";

import "package:path/path.dart" as path;
import "package:pubspec_parse/pubspec_parse.dart";

import "helper/copy.dart";

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print(
      "Only macos is supported. Usage: dart run desktop_updater:release macos",
    );
    exit(1);
  }

  final platform = args[0];
  final extraArgs = args.length > 1 ? args.sublist(1) : [];

  if (platform != "macos") {
    print(
      "Only macos is supported. Usage: dart run desktop_updater:release macos",
    );
    exit(1);
  }

  final pubspec = File("pubspec.yaml").readAsStringSync();
  final parsed = Pubspec.parse(pubspec);

  /// Only base version 1.0.0
  final buildName =
      "${parsed.version?.major}.${parsed.version?.minor}.${parsed.version?.patch}";
  final buildNumber = parsed.version?.build.firstOrNull.toString();

  print(
    "Building version $buildName+$buildNumber for $platform for app ${parsed.name}",
  );

  final appNamePubspec = parsed.name;

  // Get flutter path
  final flutterPath = Platform.environment["FLUTTER_ROOT"];

  if (flutterPath == null || flutterPath.isEmpty) {
    print("FLUTTER_ROOT environment variable is not set");
    exit(1);
  }

  // Print current working directory
  print("Current working directory: ${Directory.current.path}");

  const flutterExecutable = "flutter";

  final flutterBinPath = path.join(flutterPath, "bin", flutterExecutable);

  if (!File(flutterBinPath).existsSync()) {
    print("Flutter executable not found at path: $flutterBinPath");
    exit(1);
  }

  final buildCommand = <String>[
    flutterBinPath,
    "build",
    platform,
    "--dart-define",
    "FLUTTER_BUILD_NAME=$buildName",
    "--dart-define",
    "FLUTTER_BUILD_NUMBER=$buildNumber",
    ...extraArgs,
  ];

  print("Executing build command: ${buildCommand.join(' ')}");

  // Replace Process.run with Process.start to handle real-time output
  final process =
      await Process.start(buildCommand.first, buildCommand.sublist(1));

  process.stdout.transform(utf8.decoder).listen(print);
  process.stderr.transform(utf8.decoder).listen((data) {
    stderr.writeln(data);
  });

  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    stderr.writeln("Build failed with exit code $exitCode");
    exit(1);
  }

  print("Build completed successfully");

  final buildDir = Directory(
    path.join(
      "build",
      "macos",
      "Build",
      "Products",
      "Release",
      "$appNamePubspec.app",
    ),
  );

  if (!buildDir.existsSync()) {
    print("Build directory not found: ${buildDir.path}");
    exit(1);
  }

  final distPath = path.join(
    "dist",
    buildNumber,
    "$appNamePubspec-$buildName+$buildNumber-macos",
    "$appNamePubspec.app",
  );

  final distDir = Directory(distPath);
  if (distDir.existsSync()) {
    distDir.deleteSync(recursive: true);
  }

  // Copy buildDir to distPath
  await copyDirectory(buildDir, Directory(distPath));

  print("Archive created at $distPath");
}
