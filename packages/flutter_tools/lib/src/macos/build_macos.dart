// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:unified_analytics/unified_analytics.dart';

import '../base/analyze_size.dart';
import '../base/common.dart';
import '../base/file_system.dart';
import '../base/logger.dart';
import '../base/project_migrator.dart';
import '../base/terminal.dart';
import '../base/utils.dart';
import '../build_info.dart';
import '../convert.dart';
import '../globals.dart' as globals;
import '../ios/xcode_build_settings.dart';
import '../ios/xcodeproj.dart';
import '../migrations/xcode_project_object_version_migration.dart';
import '../migrations/xcode_script_build_phase_migration.dart';
import '../migrations/xcode_thin_binary_build_phase_input_paths_migration.dart';
import '../project.dart';
import 'application_package.dart';
import 'cocoapod_utils.dart';
import 'migrations/flutter_application_migration.dart';
import 'migrations/macos_deployment_target_migration.dart';
import 'migrations/remove_macos_framework_link_and_embedding_migration.dart';

/// When run in -quiet mode, Xcode should only print from the underlying tasks to stdout.
/// Passing this regexp to trace moves the stdout output to stderr.
///
/// Filter out xcodebuild logging unrelated to macOS builds:
/// ```none
/// xcodebuild[2096:1927385] Requested but did not find extension point with identifier Xcode.IDEKit.ExtensionPointIdentifierToBundleIdentifier for extension Xcode.DebuggerFoundation.AppExtensionToBundleIdentifierMap.watchOS of plug-in com.apple.dt.IDEWatchSupportCore
///
/// note: Using new build system
///
/// xcodebuild[61115:1017566] [MT] DVTAssertions: Warning in /System/Volumes/Data/SWE/Apps/DT/BuildRoots/BuildRoot11/ActiveBuildRoot/Library/Caches/com.apple.xbs/Sources/IDEFrameworks/IDEFrameworks-22267/IDEFoundation/Provisioning/Capabilities Infrastructure/IDECapabilityQuerySelection.swift:103
/// Details:  createItemModels creation requirements should not create capability item model for a capability item model that already exists.
/// Function: createItemModels(for:itemModelSource:)
/// Thread:   <_NSMainThread: 0x6000027c0280>{number = 1, name = main}
/// Please file a bug at https://feedbackassistant.apple.com with this warning message and any useful information you can provide.

/// ```
final RegExp _filteredOutput = RegExp(
  r'^((?!'
  r'Requested but did not find extension point with identifier|'
  r'note\:|'
  r'\[MT\] DVTAssertions: Warning in /System/Volumes/Data/SWE/|'
  r'Details\:  createItemModels|'
  r'Function\: createItemModels|'
  r'Thread\:   <_NSMainThread\:|'
  r'Please file a bug at https\://feedbackassistant\.apple\.'
  r').)*$'
  );

/// Builds the macOS project through xcodebuild.
// TODO(zanderso): refactor to share code with the existing iOS code.
Future<void> buildMacOS({
  required FlutterProject flutterProject,
  required BuildInfo buildInfo,
  String? targetOverride,
  required bool verboseLogging,
  bool configOnly = false,
  SizeAnalyzer? sizeAnalyzer,
}) async {
  final Directory? xcodeWorkspace = flutterProject.macos.xcodeWorkspace;
  if (xcodeWorkspace == null) {
    throwToolExit('No macOS desktop project configured. '
      'See https://docs.flutter.dev/desktop#add-desktop-support-to-an-existing-flutter-app '
      'to learn about adding macOS support to a project.');
  }

  final List<ProjectMigrator> migrators = <ProjectMigrator>[
    RemoveMacOSFrameworkLinkAndEmbeddingMigration(
      flutterProject.macos,
      globals.logger,
      globals.flutterUsage,
      globals.analytics,
    ),
    MacOSDeploymentTargetMigration(flutterProject.macos, globals.logger),
    XcodeProjectObjectVersionMigration(flutterProject.macos, globals.logger),
    XcodeScriptBuildPhaseMigration(flutterProject.macos, globals.logger),
    XcodeThinBinaryBuildPhaseInputPathsMigration(flutterProject.macos, globals.logger),
    FlutterApplicationMigration(flutterProject.macos, globals.logger),
  ];

  final ProjectMigration migration = ProjectMigration(migrators);
  await migration.run();

  final Directory flutterBuildDir = globals.fs.directory(getMacOSBuildDirectory());
  if (!flutterBuildDir.existsSync()) {
    flutterBuildDir.createSync(recursive: true);
  }
  // Write configuration to an xconfig file in a standard location.
  await updateGeneratedXcodeProperties(
    project: flutterProject,
    buildInfo: buildInfo,
    targetOverride: targetOverride,
    useMacOSConfig: true,
  );
  await processPodsIfNeeded(flutterProject.macos, getMacOSBuildDirectory(), buildInfo.mode);
  // If the xcfilelists do not exist, create empty version.
  if (!flutterProject.macos.inputFileList.existsSync()) {
    flutterProject.macos.inputFileList.createSync(recursive: true);
  }
  if (!flutterProject.macos.outputFileList.existsSync()) {
    flutterProject.macos.outputFileList.createSync(recursive: true);
  }
  if (configOnly) {
    return;
  }

  final Directory xcodeProject = flutterProject.macos.xcodeProject;

  // If the standard project exists, specify it to getInfo to handle the case where there are
  // other Xcode projects in the macos/ directory. Otherwise pass no name, which will work
  // regardless of the project name so long as there is exactly one project.
  final String? xcodeProjectName = xcodeProject.existsSync() ? xcodeProject.basename : null;
  final XcodeProjectInfo? projectInfo = await globals.xcodeProjectInterpreter?.getInfo(
    xcodeProject.parent.path,
    projectFilename: xcodeProjectName,
  );
  final String? scheme = projectInfo?.schemeFor(buildInfo);
  if (scheme == null) {
    projectInfo!.reportFlavorNotFoundAndExit();
  }
  final String? configuration = projectInfo?.buildConfigurationFor(buildInfo, scheme);
  if (configuration == null) {
    throwToolExit('Unable to find expected configuration in Xcode project.');
  }
  // Run the Xcode build.
  final Stopwatch sw = Stopwatch()..start();
  final Status status = globals.logger.startProgress(
    'Building macOS application...',
  );
  int result;
  try {
    result = await globals.processUtils.stream(<String>[
      '/usr/bin/env',
      'xcrun',
      'xcodebuild',
      '-workspace', xcodeWorkspace.path,
      '-configuration', configuration,
      '-scheme', scheme,
      '-derivedDataPath', flutterBuildDir.absolute.path,
      '-destination', 'platform=macOS',
      'OBJROOT=${globals.fs.path.join(flutterBuildDir.absolute.path, 'Build', 'Intermediates.noindex')}',
      'SYMROOT=${globals.fs.path.join(flutterBuildDir.absolute.path, 'Build', 'Products')}',
      if (verboseLogging)
        'VERBOSE_SCRIPT_LOGGING=YES'
      else
        '-quiet',
      'COMPILER_INDEX_STORE_ENABLE=NO',
      ...environmentVariablesAsXcodeBuildSettings(globals.platform),
    ],
    trace: true,
    stdoutErrorMatcher: verboseLogging ? null : _filteredOutput,
    mapFunction: verboseLogging ? null : (String line) => _filteredOutput.hasMatch(line) ? line : null,
  );
  } finally {
    status.cancel();
  }

  if (result != 0) {
    throwToolExit('Build process failed');
  }
  final String? applicationBundle = MacOSApp.fromMacOSProject(flutterProject.macos).applicationBundle(buildInfo);
  if (applicationBundle != null) {
    final Directory outputDirectory = globals.fs.directory(applicationBundle);
    // This output directory is the .app folder itself.
    final int? directorySize = globals.os.getDirectorySize(outputDirectory);
    final String appSize = (buildInfo.mode == BuildMode.debug || directorySize == null)
        ? '' // Don't display the size when building a debug variant.
        : ' (${getSizeAsPlatformMB(directorySize)})';
    globals.printStatus(
      '${globals.terminal.successMark} '
      'Built ${globals.fs.path.relative(outputDirectory.path)}$appSize',
      color: TerminalColor.green,
    );
  }
  await _writeCodeSizeAnalysis(buildInfo, sizeAnalyzer);
  final Duration elapsedDuration = sw.elapsed;
  globals.flutterUsage.sendTiming('build', 'xcode-macos', elapsedDuration);
  globals.analytics.send(Event.timing(
    workflow: 'build',
    variableName: 'xcode-macos',
    elapsedMilliseconds: elapsedDuration.inMilliseconds,
  ));
}

/// Performs a size analysis of the AOT snapshot and writes to an analysis file, if configured.
///
/// Size analysis will be run for release builds where the --analyze-size
/// option has been specified. By default, size analysis JSON output is written
/// to ~/.flutter-devtools/macos-code-size-analysis_NN.json.
Future<void> _writeCodeSizeAnalysis(BuildInfo buildInfo, SizeAnalyzer? sizeAnalyzer) async {
  // Bail out if the size analysis option was not specified.
  if (buildInfo.codeSizeDirectory == null || sizeAnalyzer == null) {
    return;
  }
  final File? aotSnapshot = DarwinArch.values.map<File?>((DarwinArch arch) {
    return globals.fs.directory(buildInfo.codeSizeDirectory).childFile('snapshot.${arch.name}.json');
    // Pick the first if there are multiple for simplicity
  }).firstWhere(
    (File? file) => file!.existsSync(),
    orElse: () => null,
  );
  if (aotSnapshot == null) {
    throw StateError('No code size snapshot file (snapshot.<ARCH>.json) found in ${buildInfo.codeSizeDirectory}');
  }
  final File? precompilerTrace = DarwinArch.values.map<File?>((DarwinArch arch) {
    return globals.fs.directory(buildInfo.codeSizeDirectory).childFile('trace.${arch.name}.json');
  }).firstWhere(
    (File? file) => file!.existsSync(),
    orElse: () => null,
  );
  if (precompilerTrace == null) {
    throw StateError('No precompiler trace file (trace.<ARCH>.json) found in ${buildInfo.codeSizeDirectory}');
  }

  // This analysis is only supported for release builds.
  // Attempt to guess the correct .app by picking the first one.
  final Directory candidateDirectory = globals.fs.directory(
    globals.fs.path.join(getMacOSBuildDirectory(), 'Build', 'Products', 'Release'),
  );
  final Directory appDirectory = candidateDirectory.listSync()
    .whereType<Directory>()
    .firstWhere((Directory directory) {
    return globals.fs.path.extension(directory.path) == '.app';
  });
  final Map<String, Object?> output = await sizeAnalyzer.analyzeAotSnapshot(
    aotSnapshot: aotSnapshot,
    precompilerTrace: precompilerTrace,
    outputDirectory: appDirectory,
    type: 'macos',
    excludePath: 'Versions', // Avoid double counting caused by symlinks
  );
  final File outputFile = globals.fsUtils.getUniqueFile(
    globals.fs
      .directory(globals.fsUtils.homeDirPath)
      .childDirectory('.flutter-devtools'), 'macos-code-size-analysis', 'json',
  )..writeAsStringSync(jsonEncode(output));
  // This message is used as a sentinel in analyze_apk_size_test.dart
  globals.printStatus(
    'A summary of your macOS bundle analysis can be found at: ${outputFile.path}',
  );

  // DevTools expects a file path relative to the .flutter-devtools/ dir.
  final String relativeAppSizePath = outputFile.path.split('.flutter-devtools/').last.trim();
  globals.printStatus(
    '\nTo analyze your app size in Dart DevTools, run the following command:\n'
    'dart devtools --appSizeBase=$relativeAppSizePath'
  );
}
