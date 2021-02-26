// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:file/memory.dart';
import 'package:file_testing/file_testing.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/build_system/targets/assets.dart';
import 'package:flutter_tools/src/build_system/targets/common.dart';
import 'package:flutter_tools/src/build_system/targets/ios.dart';
import 'package:flutter_tools/src/convert.dart';

import '../../../src/common.dart';
import '../../../src/context.dart';

final Platform macPlatform = FakePlatform(operatingSystem: 'macos', environment: <String, String>{});

const List<String> _kSharedConfig = <String>[
  '-dynamiclib',
  '-fembed-bitcode-marker',
  '-miphoneos-version-min=8.0',
  '-Xlinker',
  '-rpath',
  '-Xlinker',
  '@executable_path/Frameworks',
  '-Xlinker',
  '-rpath',
  '-Xlinker',
  '@loader_path/Frameworks',
  '-install_name',
  '@rpath/App.framework/App',
  '-isysroot',
  'path/to/sdk',
];

void main() {
  Environment environment;
  FileSystem fileSystem;
  FakeProcessManager processManager;
  Artifacts artifacts;
  BufferLogger logger;

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    processManager = FakeProcessManager.list(<FakeCommand>[]);
    logger = BufferLogger.test();
    artifacts = Artifacts.test();
    environment = Environment.test(
      fileSystem.currentDirectory,
      defines: <String, String>{
        kTargetPlatform: 'ios',
      },
      inputs: <String, String>{},
      processManager: processManager,
      artifacts: artifacts,
      logger: logger,
      fileSystem: fileSystem,
      engineVersion: '2',
    );
  });

  testWithoutContext('iOS AOT targets has analyicsName', () {
    expect(const AotAssemblyRelease().analyticsName, 'ios_aot');
    expect(const AotAssemblyProfile().analyticsName, 'ios_aot');
  });

  testUsingContext('DebugUniveralFramework creates expected binary with arm64 only arch', () async {
    environment.defines[kIosArchs] = 'arm64';
    environment.defines[kSdkRoot] = 'path/to/sdk';
    processManager.addCommand(
      FakeCommand(command: <String>[
        'xcrun',
        'clang',
        '-x',
        'c',
        // iphone only gets 64 bit arch based on kIosArchs
        '-arch',
        'arm64',
        fileSystem.path.absolute(fileSystem.path.join(
            '.tmp_rand0', 'flutter_tools_stub_source.rand0', 'debug_app.cc')),
        ..._kSharedConfig,
        '-o',
        environment.buildDir
            .childDirectory('App.framework')
            .childFile('App')
            .path,
      ]),
    );

    await const DebugUniversalFramework().build(environment);
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => processManager,
    Platform: () => macPlatform,
  });

  testUsingContext('DebugIosApplicationBundle', () async {
    environment.inputs[kBundleSkSLPath] = 'bundle.sksl';
    environment.defines[kBuildMode] = 'debug';
    // Precompiled dart data

    fileSystem.file(artifacts.getArtifactPath(Artifact.vmSnapshotData, mode: BuildMode.debug))
      .createSync();
    fileSystem.file(artifacts.getArtifactPath(Artifact.isolateSnapshotData, mode: BuildMode.debug))
      .createSync();
    // Project info
    fileSystem.file('pubspec.yaml').writeAsStringSync('name: hello');
    fileSystem.file('.packages').writeAsStringSync('\n');
    // Plist file
    fileSystem.file(fileSystem.path.join('ios', 'Flutter', 'AppFrameworkInfo.plist'))
      .createSync(recursive: true);
    // App kernel
    environment.buildDir.childFile('app.dill').createSync(recursive: true);
    // Stub framework
    environment.buildDir
      .childDirectory('App.framework')
      .childFile('App')
      .createSync(recursive: true);
    // sksl bundle
    fileSystem.file('bundle.sksl').writeAsStringSync(json.encode(
      <String, Object>{
        'engineRevision': '2',
        'platform': 'ios',
        'data': <String, Object>{
          'A': 'B',
        }
      }
    ));

    await const DebugIosApplicationBundle().build(environment);

    final Directory frameworkDirectory = environment.outputDir.childDirectory('App.framework');
    expect(frameworkDirectory.childFile('App'), exists);
    expect(frameworkDirectory.childFile('Info.plist'), exists);

    final Directory assetDirectory = frameworkDirectory.childDirectory('flutter_assets');
    expect(assetDirectory.childFile('kernel_blob.bin'), exists);
    expect(assetDirectory.childFile('AssetManifest.json'), exists);
    expect(assetDirectory.childFile('vm_snapshot_data'), exists);
    expect(assetDirectory.childFile('isolate_snapshot_data'), exists);
    expect(assetDirectory.childFile('io.flutter.shaders.json'), exists);
    expect(assetDirectory.childFile('io.flutter.shaders.json').readAsStringSync(), '{"data":{"A":"B"}}');
  });

  testUsingContext('ReleaseIosApplicationBundle', () async {
    environment.defines[kBuildMode] = 'release';

    // Project info
    fileSystem.file('pubspec.yaml').writeAsStringSync('name: hello');
    fileSystem.file('.packages').writeAsStringSync('\n');
    // Plist file
    fileSystem.file(fileSystem.path.join('ios', 'Flutter', 'AppFrameworkInfo.plist'))
      .createSync(recursive: true);

    // Real framework
    environment.buildDir
      .childDirectory('App.framework')
      .childFile('App')
      .createSync(recursive: true);

    await const ReleaseIosApplicationBundle().build(environment);

    final Directory frameworkDirectory = environment.outputDir.childDirectory('App.framework');
    expect(frameworkDirectory.childFile('App'), exists);
    expect(frameworkDirectory.childFile('Info.plist'), exists);

    final Directory assetDirectory = frameworkDirectory.childDirectory('flutter_assets');
    expect(assetDirectory.childFile('kernel_blob.bin'), isNot(exists));
    expect(assetDirectory.childFile('AssetManifest.json'), exists);
    expect(assetDirectory.childFile('vm_snapshot_data'), isNot(exists));
    expect(assetDirectory.childFile('isolate_snapshot_data'), isNot(exists));
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => processManager,
    Platform: () => macPlatform,
  });

  testUsingContext('AotAssemblyRelease throws exception if asked to build for simulator', () async {
    final FileSystem fileSystem = MemoryFileSystem.test();
    final Environment environment = Environment.test(
      fileSystem.currentDirectory,
      defines: <String, String>{
        kTargetPlatform: 'ios',
        kSdkRoot: 'path/to/iPhoneSimulator.sdk',
        kBuildMode: 'release',
        kIosArchs: 'x86_64',
      },
      processManager: processManager,
      artifacts: artifacts,
      logger: logger,
      fileSystem: fileSystem,
    );

    expect(const AotAssemblyRelease().build(environment), throwsA(isA<Exception>()
      .having(
        (Exception exception) => exception.toString(),
        'description',
        contains('release/profile builds are only supported for physical devices.'),
      )
    ));
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => processManager,
    Platform: () => macPlatform,
  });

  testUsingContext('AotAssemblyRelease throws exception if sdk root is missing', () async {
    final FileSystem fileSystem = MemoryFileSystem.test();
    final Environment environment = Environment.test(
      fileSystem.currentDirectory,
      defines: <String, String>{
        kTargetPlatform: 'ios',
      },
      processManager: processManager,
      artifacts: artifacts,
      logger: logger,
      fileSystem: fileSystem,
    );
    environment.defines[kBuildMode] = 'release';
    environment.defines[kIosArchs] = 'x86_64';

    expect(const AotAssemblyRelease().build(environment), throwsA(isA<Exception>()
        .having(
          (Exception exception) => exception.toString(),
      'description',
      contains('required define SdkRoot but it was not provided'),
    )
    ));
  }, overrides: <Type, Generator>{
    FileSystem: () => fileSystem,
    ProcessManager: () => processManager,
    Platform: () => macPlatform,
  });

  group('copy engine Flutter.framework', () {
    testWithoutContext('iphonesimulator', () async {
      final FileSystem fileSystem = MemoryFileSystem.test();
      final Directory outputDir = fileSystem.directory('output');
      final Environment environment = Environment.test(
        fileSystem.currentDirectory,
        processManager: processManager,
        artifacts: artifacts,
        logger: logger,
        fileSystem: fileSystem,
        outputDir: outputDir,
        defines: <String, String>{
          kSdkRoot: 'path/to/iPhoneSimulator.sdk',
        },
      );

      processManager.addCommand(
        FakeCommand(command: <String>[
          'rsync',
          '-av',
          '--delete',
          '--filter',
          '- .DS_Store/',
          'Artifact.flutterFramework.TargetPlatform.ios.debug.EnvironmentType.simulator',
          outputDir.path,
        ]),
      );

      await const DebugUnpackIOS().build(environment);
    });

    testWithoutContext('iphoneos', () async {
      final FileSystem fileSystem = MemoryFileSystem.test();
      final Directory outputDir = fileSystem.directory('output');
      final Environment environment = Environment.test(
        fileSystem.currentDirectory,
        processManager: processManager,
        artifacts: artifacts,
        logger: logger,
        fileSystem: fileSystem,
        outputDir: outputDir,
        defines: <String, String>{
          kSdkRoot: 'path/to/iPhoneOS.sdk',
        },
      );

      processManager.addCommand(
        FakeCommand(command: <String>[
          'rsync',
          '-av',
          '--delete',
          '--filter',
          '- .DS_Store/',
          'Artifact.flutterFramework.TargetPlatform.ios.debug.EnvironmentType.physical',
          outputDir.path,
        ]),
      );

      await const DebugUnpackIOS().build(environment);
    });
  });

  group('thin frameworks', () {
    testWithoutContext('do not skip when archs not requested', () async {
      final FileSystem fileSystem = MemoryFileSystem.test();
      final Directory outputDir = fileSystem.directory('Runner.app').childDirectory('Frameworks')..createSync(recursive: true);

      final Environment environment = Environment.test(
        fileSystem.currentDirectory,
        processManager: processManager,
        artifacts: artifacts,
        logger: logger,
        fileSystem: fileSystem,
        outputDir: outputDir,
        defines: <String, String>{},
      );
      expect(ThinIosApplicationFrameworks().canSkip(environment), isFalse);
      expect(processManager.hasRemainingExpectations, isFalse);
    });

    testWithoutContext('do not skip when requested archs missing from framework', () async {
      final FileSystem fileSystem = MemoryFileSystem.test();
      final Directory outputDir = fileSystem.directory('Runner.app').childDirectory('Frameworks')..createSync(recursive: true);
      final File binary = outputDir.childDirectory('Flutter.framework').childFile('Flutter')..createSync(recursive: true);

      final Environment environment = Environment.test(
        fileSystem.currentDirectory,
        processManager: processManager,
        artifacts: artifacts,
        logger: logger,
        fileSystem: fileSystem,
        outputDir: outputDir,
        defines: <String, String>{
          kIosArchs: 'arm64 armv7',
        },
      );

      processManager.addCommand(
        FakeCommand(command: <String>[
          'lipo',
          '-info',
          binary.path,
        ], stdout: 'Non-fat file: Flutter.framework/Flutter is architecture: arm64'),
      );
      expect(ThinIosApplicationFrameworks().canSkip(environment), isFalse);
    });

    testWithoutContext('do not skip when lipo -info fails', () async {
      final FileSystem fileSystem = MemoryFileSystem.test();
      final Directory outputDir = fileSystem.directory('Runner.app').childDirectory('Frameworks')..createSync(recursive: true);
      final File binary = outputDir.childDirectory('Flutter.framework').childFile('Flutter')..createSync(recursive: true);

      final Environment environment = Environment.test(
        fileSystem.currentDirectory,
        processManager: processManager,
        artifacts: artifacts,
        logger: logger,
        fileSystem: fileSystem,
        outputDir: outputDir,
        defines: <String, String>{
          kIosArchs: 'arm64 armv7',
        },
      );

      processManager.addCommand(
        FakeCommand(command: <String>[
          'lipo',
          '-info',
          binary.path,
        ], exitCode: 1),
      );
      expect(ThinIosApplicationFrameworks().canSkip(environment), isFalse);
    });

    testWithoutContext('do not skip when cannot parse lipo', () async {
      final FileSystem fileSystem = MemoryFileSystem.test();
      final Directory outputDir = fileSystem.directory('Runner.app').childDirectory('Frameworks')..createSync(recursive: true);
      final File binary = outputDir.childDirectory('Flutter.framework').childFile('Flutter')..createSync(recursive: true);

      final Environment environment = Environment.test(
        fileSystem.currentDirectory,
        processManager: processManager,
        artifacts: artifacts,
        logger: logger,
        fileSystem: fileSystem,
        outputDir: outputDir,
        defines: <String, String>{
          kIosArchs: 'arm64 armv7',
        },
      );

      processManager.addCommand(
        FakeCommand(command: <String>[
          'lipo',
          '-info',
          binary.path,
        ], stdout: 'Bogus output'),
      );
      expect(ThinIosApplicationFrameworks().canSkip(environment), isFalse);
    });

    testWithoutContext('do not skip when thinning is required', () async {
      final FileSystem fileSystem = MemoryFileSystem.test();
      final Directory outputDir = fileSystem.directory('Runner.app').childDirectory('Frameworks')..createSync(recursive: true);
      final File binary = outputDir.childDirectory('Flutter.framework').childFile('Flutter')..createSync(recursive: true);

      final Environment environment = Environment.test(
        fileSystem.currentDirectory,
        processManager: processManager,
        artifacts: artifacts,
        logger: logger,
        fileSystem: fileSystem,
        outputDir: outputDir,
        defines: <String, String>{
          kIosArchs: 'arm64',
        },
      );

      processManager.addCommand(
        FakeCommand(command: <String>[
          'lipo',
          '-info',
          binary.path,
        ], stdout: 'Architectures in the fat file: Flutter.framework/Flutter are: armv7 arm64 '),
      );

      final ThinIosApplicationFrameworks thinIosApplicationFrameworks = ThinIosApplicationFrameworks();
      expect(thinIosApplicationFrameworks.canSkip(environment), isFalse);
      expect(processManager.hasRemainingExpectations, isFalse);

      processManager.addCommand(
        FakeCommand(command: <String>[
          'lipo',
          '-output',
          binary.path,
          '-extract',
          'arm64',
          binary.path,
        ]),
      );

      await thinIosApplicationFrameworks.build(environment);
      expect(processManager.hasRemainingExpectations, isFalse);
    });

    testWithoutContext('skip when thinning is not required for fat', () async {
      final FileSystem fileSystem = MemoryFileSystem.test();
      final Directory outputDir = fileSystem.directory('Runner.app').childDirectory('Frameworks')..createSync(recursive: true);
      final File binary = outputDir.childDirectory('Flutter.framework').childFile('Flutter')..createSync(recursive: true);

      final Environment environment = Environment.test(
        fileSystem.currentDirectory,
        processManager: processManager,
        artifacts: artifacts,
        logger: logger,
        fileSystem: fileSystem,
        outputDir: outputDir,
        defines: <String, String>{
          kIosArchs: 'armv7 arm64',
        },
      );

      processManager.addCommand(
        FakeCommand(command: <String>[
          'lipo',
          '-info',
          binary.path,
        ], stdout: 'Architectures in the fat file: Flutter.framework/Flutter are: arm64 armv7 '), // arch order doesn't matter
      );

      expect(ThinIosApplicationFrameworks().canSkip(environment), isTrue);
    });

    testWithoutContext('skip when thinning is not required for non-fat', () async {
      final FileSystem fileSystem = MemoryFileSystem.test();
      final Directory outputDir = fileSystem.directory('Runner.app').childDirectory('Frameworks')..createSync(recursive: true);
      final File binary = outputDir.childDirectory('Flutter.framework').childFile('Flutter')..createSync(recursive: true);

      final Environment environment = Environment.test(
        fileSystem.currentDirectory,
        processManager: processManager,
        artifacts: artifacts,
        logger: logger,
        fileSystem: fileSystem,
        outputDir: outputDir,
        defines: <String, String>{
          kIosArchs: 'x86_64',
        },
      );

      processManager.addCommand(
        FakeCommand(command: <String>[
          'lipo',
          '-info',
          binary.path,
        ], stdout: 'Non-fat file: Flutter.framework/Flutter is architecture: x86_64'),
      );
      expect(ThinIosApplicationFrameworks().canSkip(environment), isTrue);
    });

    testWithoutContext('fails when frameworks missing', () async {
      final FileSystem fileSystem = MemoryFileSystem.test();
      final Directory outputDir = fileSystem.directory('Runner.app').childDirectory('Frameworks');
      final Environment environment = Environment.test(
        fileSystem.currentDirectory,
        processManager: processManager,
        artifacts: artifacts,
        logger: logger,
        fileSystem: fileSystem,
        outputDir: outputDir,
        defines: <String, String>{
          kIosArchs: 'arm64',
        },
      );
      await expectLater(
        ThinIosApplicationFrameworks().build(environment),
        throwsA(isA<Exception>().having(
          (Exception exception) => exception.toString(),
          'description',
          contains('Flutter.framework/Flutter does not exist, cannot thin'),
        )));
    });

    testWithoutContext('fails when requested archs missing from framework', () async {
      final FileSystem fileSystem = MemoryFileSystem.test();
      final Directory outputDir = fileSystem.directory('Runner.app').childDirectory('Frameworks')..createSync(recursive: true);
      final File binary = outputDir.childDirectory('Flutter.framework').childFile('Flutter')..createSync(recursive: true);

      final Environment environment = Environment.test(
        fileSystem.currentDirectory,
        processManager: processManager,
        artifacts: artifacts,
        logger: logger,
        fileSystem: fileSystem,
        outputDir: outputDir,
        defines: <String, String>{
          kIosArchs: 'arm64 armv7',
        },
      );

      processManager.addCommand(
        FakeCommand(command: <String>[
          'lipo',
          '-info',
          binary.path,
        ], stdout: 'Non-fat file: Flutter.framework/Flutter is architecture: arm64'),
      );

      await expectLater(
          ThinIosApplicationFrameworks().build(environment),
          throwsA(isA<Exception>().having(
                (Exception exception) => exception.toString(),
            'description',
            contains('does not contain arm64 armv7. Running lipo -info:\nNon-fat file:'),
          )));
    });


    testWithoutContext('fails when cannot parse lipo', () async {
      final FileSystem fileSystem = MemoryFileSystem.test();
      final Directory outputDir = fileSystem.directory('Runner.app').childDirectory('Frameworks')..createSync(recursive: true);
      final File binary = outputDir.childDirectory('Flutter.framework').childFile('Flutter')..createSync(recursive: true);

      final Environment environment = Environment.test(
        fileSystem.currentDirectory,
        processManager: processManager,
        artifacts: artifacts,
        logger: logger,
        fileSystem: fileSystem,
        outputDir: outputDir,
        defines: <String, String>{
          kIosArchs: 'arm64 armv7',
        },
      );

      processManager.addCommand(
        FakeCommand(command: <String>[
          'lipo',
          '-info',
          binary.path,
        ], stdout: 'Bogus output'),
      );

      await expectLater(
          ThinIosApplicationFrameworks().build(environment),
          throwsA(isA<Exception>().having(
                (Exception exception) => exception.toString(),
            'description',
            contains('does not contain arm64 armv7. Running lipo -info:\nBogus output'),
          )));
    });

    testWithoutContext('fails when lipo extract fails', () async {
      final FileSystem fileSystem = MemoryFileSystem.test();
      final Directory outputDir = fileSystem.directory('Runner.app').childDirectory('Frameworks')..createSync(recursive: true);
      final File binary = outputDir.childDirectory('Flutter.framework').childFile('Flutter')..createSync(recursive: true);

      final Environment environment = Environment.test(
        fileSystem.currentDirectory,
        processManager: processManager,
        artifacts: artifacts,
        logger: logger,
        fileSystem: fileSystem,
        outputDir: outputDir,
        defines: <String, String>{
          kIosArchs: 'arm64 armv7',
        },
      );

      processManager.addCommand(
        FakeCommand(command: <String>[
          'lipo',
          '-info',
          binary.path,
        ], stdout: 'Architectures in the fat file: Flutter.framework/Flutter are: armv7 arm64 '),
      );

      processManager.addCommand(
        FakeCommand(command: <String>[
          'lipo',
          '-output',
          binary.path,
          '-extract',
          'arm64',
          '-extract',
          'armv7',
          binary.path,
        ], exitCode: 1,
        stderr: 'lipo error'),
      );

      await expectLater(
        ThinIosApplicationFrameworks().build(environment),
        throwsA(isA<Exception>().having(
              (Exception exception) => exception.toString(),
          'description',
          contains('Failed to extract arm64 armv7 for Runner.app/Frameworks/Flutter.framework/Flutter.\nlipo error\nRunning lipo -info:\nArchitectures in the fat file:'),
        )));
    });

    testWithoutContext('skips thin frameworks', () async {
      final FileSystem fileSystem = MemoryFileSystem.test();
      final Directory outputDir = fileSystem.directory('Runner.app').childDirectory('Frameworks')..createSync(recursive: true);
      final File binary = outputDir.childDirectory('Flutter.framework').childFile('Flutter')..createSync(recursive: true);

      final Environment environment = Environment.test(
        fileSystem.currentDirectory,
        processManager: processManager,
        artifacts: artifacts,
        logger: logger,
        fileSystem: fileSystem,
        outputDir: outputDir,
        defines: <String, String>{
          kIosArchs: 'arm64',
        },
      );

      processManager.addCommand(
        FakeCommand(command: <String>[
          'lipo',
          '-info',
          binary.path,
        ], stdout: 'Non-fat file: Flutter.framework/Flutter is architecture: arm64'),
      );
      await ThinIosApplicationFrameworks().build(environment);

      expect(logger.traceText, contains('Skipping lipo for non-fat file Runner.app/Frameworks/Flutter.framework/Flutter'));

      expect(processManager.hasRemainingExpectations, isFalse);
    });

    testWithoutContext('thins fat frameworks', () async {
      final FileSystem fileSystem = MemoryFileSystem.test();
      final Directory outputDir = fileSystem.directory('Runner.app').childDirectory('Frameworks')..createSync(recursive: true);
      final File binary = outputDir.childDirectory('Flutter.framework').childFile('Flutter')..createSync(recursive: true);

      final Environment environment = Environment.test(
        fileSystem.currentDirectory,
        processManager: processManager,
        artifacts: artifacts,
        logger: logger,
        fileSystem: fileSystem,
        outputDir: outputDir,
        defines: <String, String>{
          kIosArchs: 'arm64 armv7',
        },
      );

      processManager.addCommand(
        FakeCommand(command: <String>[
          'lipo',
          '-info',
          binary.path,
        ], stdout: 'Architectures in the fat file: Flutter.framework/Flutter are: armv7 arm64 '),
      );

      processManager.addCommand(
        FakeCommand(command: <String>[
          'lipo',
          '-output',
          binary.path,
          '-extract',
          'arm64',
          '-extract',
          'armv7',
          binary.path,
        ]),
      );

      await ThinIosApplicationFrameworks().build(environment);
      expect(processManager.hasRemainingExpectations, isFalse);
    });
  });
}
