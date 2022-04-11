// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:args/command_runner.dart';
import 'package:conductor_core/src/codesign.dart';
import 'package:conductor_core/src/repository.dart';
import 'package:file/memory.dart';
import 'package:platform/platform.dart';

import './common.dart';

void main() {
  const String flutterRoot = '/flutter';
  const String checkoutsParentDirectory = '$flutterRoot/dev/conductor/';
  const String flutterCache =
      '${checkoutsParentDirectory}flutter_conductor_checkouts/framework/bin/cache';
  const String flutterBin =
      '${checkoutsParentDirectory}flutter_conductor_checkouts/framework/bin/flutter';
  const String revision = 'abcd1234';
  late CommandRunner<void> runner;
  late Checkouts checkouts;
  late MemoryFileSystem fileSystem;
  late FakePlatform platform;
  late TestStdio stdio;
  late FakeProcessManager processManager;
  const List<String> binariesWithEntitlements = <String>[
    '$flutterCache/dart-sdk/bin/dart',
    '$flutterCache/dart-sdk/bin/dartaotruntime',
  ];
  const List<String> binariesWithoutEntitlements = <String>[
    '$flutterCache/engine/darwin-x64/font-subset',
  ];
  const List<String> allBinaries = <String>[
    ...binariesWithEntitlements,
    ...binariesWithoutEntitlements,
  ];
  const String certName = 'flutter';
  const String engineRevision = 'deadbeef';

  void createRunner({
    String operatingSystem = 'macos',
    List<FakeCommand>? commands,
  }) {
    stdio = TestStdio();
    fileSystem = MemoryFileSystem.test();
    // create engine version hash
    fileSystem.file('flutter/bin/internal/engine.version')
        ..createSync(recursive: true)
        ..writeAsStringSync(engineRevision);
    platform = FakePlatform(
      operatingSystem: operatingSystem,
      environment: <String, String>{},
    );
    processManager = FakeProcessManager.list(commands ?? <FakeCommand>[]);
    checkouts = Checkouts(
      fileSystem: fileSystem,
      parentDirectory: fileSystem.directory(checkoutsParentDirectory),
      platform: platform,
      processManager: processManager,
      stdio: stdio,
    );
    final FakeCodesignCommand command = FakeCodesignCommand(
      checkouts: checkouts,
      binariesWithEntitlementsOverride: binariesWithEntitlements,
      binariesWithoutEntitlementsOverride: binariesWithoutEntitlements,
      flutterRoot: fileSystem.directory(flutterRoot),
    );
    runner = CommandRunner<void>('codesign-test', '')
      ..addCommand(command);
  }


  group('codesign', () {
    test('foo', () async {
      createRunner();
      processManager.addCommands(const <FakeCommand>[
        FakeCommand(command: <String>[
          'git',
          'clone',
          '--origin',
          'upstream',
          '--',
          'file://$flutterRoot/',
          '${checkoutsParentDirectory}flutter_conductor_checkouts/framework',
        ]),
        FakeCommand(command: <String>[
          'git',
          'checkout',
          FrameworkRepository.defaultBranch,
        ]),
        FakeCommand(command: <String>[
          'git',
          'rev-parse',
          'HEAD',
        ], stdout: revision),
        FakeCommand(command: <String>[
          'git',
          'rev-parse',
          'HEAD',
        ], stdout: revision),
      ]);
      await runner.run(<String>[
        'codesign',
        '--$kCodesignCertName',
        certName,
      ]);

      expect(processManager, hasNoRemainingExpectations);
    });
  });

  group('codesign --verify', () {
    test('throws exception if not run from macos', () async {
      createRunner(operatingSystem: 'linux');
      expect(
        () async => runner.run(<String>['codesign']),
        throwsExceptionWith('Error! Expected operating system "macos"'),
      );
    });

    test('does not fail if --revision flag not provided', () async {
      final List<FakeCommand> codesignCheckCommands = <FakeCommand>[];
      for (final String bin in binariesWithEntitlements) {
        codesignCheckCommands.add(
          FakeCommand(
            command: <String>['codesign', '-vvv', bin],
          ),
        );
        codesignCheckCommands.add(
          FakeCommand(
            command: <String>['codesign', '--display', '--entitlements', ':-', bin],
            stdout: expectedEntitlements.join('\n'),
          ),
        );
      }
      for (final String bin in binariesWithoutEntitlements) {
        codesignCheckCommands.add(
          FakeCommand(
            command: <String>['codesign', '-vvv', bin],
          ),
        );
      }
      createRunner(commands: <FakeCommand>[
        const FakeCommand(command: <String>[
          'git',
          'rev-parse',
          'HEAD',
        ], stdout: revision),
        const FakeCommand(command: <String>[
          'git',
          'clone',
          '--origin',
          'upstream',
          '--',
          FrameworkRepository.defaultUpstream,
          '${checkoutsParentDirectory}flutter_conductor_checkouts/framework',
        ]),
        const FakeCommand(command: <String>[
          'git',
          'checkout',
          FrameworkRepository.defaultBranch,
        ]),
        const FakeCommand(command: <String>[
          'git',
          'rev-parse',
          'HEAD',
        ], stdout: revision),
        const FakeCommand(command: <String>[
          'git',
          'checkout',
          revision,
        ]),
        const FakeCommand(command: <String>[
          flutterBin,
          'help',
        ]),
        const FakeCommand(command: <String>[
          flutterBin,
          'help',
        ]),
        const FakeCommand(command: <String>[
          flutterBin,
          'precache',
          '--android',
          '--ios',
          '--macos',
        ]),
        FakeCommand(
          command: const <String>[
            'find',
            '${checkoutsParentDirectory}flutter_conductor_checkouts/framework/bin/cache',
            '-type',
            'f',
          ],
          stdout: allBinaries.join('\n'),
        ),
        for (String bin in allBinaries)
          FakeCommand(
            command: <String>['file', '--mime-type', '-b', bin],
            stdout: 'application/x-mach-binary',
          ),
        ...codesignCheckCommands,
      ]);
      await runner.run(<String>['codesign', '--$kVerify']);
      expect(processManager.hasRemainingExpectations, false);
      expect(stdio.stdout, contains('Verified that binaries are codesigned and have expected entitlements'));
    });

    test('framework cloned from repo provided by --$kUpstream', () async {
      const String upstreamRepo = 'https://githost.org/org/project';
      final List<FakeCommand> codesignCheckCommands = <FakeCommand>[];
      for (final String bin in binariesWithEntitlements) {
        codesignCheckCommands.add(
          FakeCommand(
            command: <String>['codesign', '-vvv', bin],
          ),
        );
        codesignCheckCommands.add(
          FakeCommand(
            command: <String>['codesign', '--display', '--entitlements', ':-', bin],
            stdout: expectedEntitlements.join('\n'),
          ),
        );
      }
      for (final String bin in binariesWithoutEntitlements) {
        codesignCheckCommands.add(
          FakeCommand(
            command: <String>['codesign', '-vvv', bin],
          ),
        );
      }
      createRunner(commands: <FakeCommand>[
        const FakeCommand(command: <String>[
          'git',
          'clone',
          '--origin',
          'upstream',
          '--',
          upstreamRepo,
          '${checkoutsParentDirectory}flutter_conductor_checkouts/framework',
        ]),
        const FakeCommand(command: <String>[
          'git',
          'checkout',
          FrameworkRepository.defaultBranch,
        ]),
        const FakeCommand(command: <String>[
          'git',
          'rev-parse',
          'HEAD',
        ], stdout: revision),
        const FakeCommand(command: <String>[
          'git',
          'checkout',
          revision,
        ]),
        const FakeCommand(command: <String>[
          flutterBin,
          'help',
        ]),
        const FakeCommand(command: <String>[
          flutterBin,
          'help',
        ]),
        const FakeCommand(command: <String>[
          flutterBin,
          'precache',
          '--android',
          '--ios',
          '--macos',
        ]),
        FakeCommand(
          command: const <String>[
            'find',
            '${checkoutsParentDirectory}flutter_conductor_checkouts/framework/bin/cache',
            '-type',
            'f',
          ],
          stdout: allBinaries.join('\n'),
        ),
        for (String bin in allBinaries)
          FakeCommand(
            command: <String>['file', '--mime-type', '-b', bin],
            stdout: 'application/x-mach-binary',
          ),
        ...codesignCheckCommands,
      ]);
      await runner.run(<String>[
        'codesign',
        '--$kVerify',
        '--$kRevision',
        revision,
        '--$kUpstream',
        upstreamRepo,
      ]);
      expect(processManager, hasNoRemainingExpectations);
      expect(stdio.stdout, contains('Verified that binaries for commit $revision are codesigned and have expected entitlements'));
    });

    test('succeeds if every binary is codesigned and has correct entitlements', () async {
      final List<FakeCommand> codesignCheckCommands = <FakeCommand>[];
      for (final String bin in binariesWithEntitlements) {
        codesignCheckCommands.add(
          FakeCommand(
            command: <String>['codesign', '-vvv', bin],
          ),
        );
        codesignCheckCommands.add(
          FakeCommand(
            command: <String>['codesign', '--display', '--entitlements', ':-', bin],
            stdout: expectedEntitlements.join('\n'),
          ),
        );
      }
      for (final String bin in binariesWithoutEntitlements) {
        codesignCheckCommands.add(
          FakeCommand(
            command: <String>['codesign', '-vvv', bin],
          ),
        );
      }
      createRunner(commands: <FakeCommand>[
        const FakeCommand(command: <String>[
          'git',
          'clone',
          '--origin',
          'upstream',
          '--',
          FrameworkRepository.defaultUpstream,
          '${checkoutsParentDirectory}flutter_conductor_checkouts/framework',
        ]),
        const FakeCommand(command: <String>[
          'git',
          'checkout',
          revision,
        ]),
        const FakeCommand(command: <String>[
          'git',
          'rev-parse',
          'HEAD',
        ], stdout: revision),
        const FakeCommand(command: <String>[
          'git',
          'rev-parse',
          'HEAD',
        ], stdout: revision),
        const FakeCommand(command: <String>[
          'git',
          'checkout',
          revision,
        ]),
        const FakeCommand(command: <String>[
          flutterBin,
          'help',
        ]),
        const FakeCommand(command: <String>[
          flutterBin,
          'help',
        ]),
        const FakeCommand(command: <String>[
          flutterBin,
          'precache',
          '--android',
          '--ios',
          '--macos',
        ]),
        FakeCommand(
          command: const <String>[
            'find',
            '${checkoutsParentDirectory}flutter_conductor_checkouts/framework/bin/cache',
            '-type',
            'f',
          ],
          stdout: allBinaries.join('\n'),
        ),
        for (String bin in allBinaries)
          FakeCommand(
            command: <String>['file', '--mime-type', '-b', bin],
            stdout: 'application/x-mach-binary',
          ),
        ...codesignCheckCommands,
      ]);
      await runner.run(<String>['codesign', '--$kVerify', '--$kRevision', revision]);
      expect(processManager.hasRemainingExpectations, false);
      expect(stdio.stdout, contains('Verified that binaries are codesigned and have expected entitlements'));
    });

    test('fails if a single binary is not codesigned', () async {
      final List<FakeCommand> codesignCheckCommands = <FakeCommand>[];
      codesignCheckCommands.add(
        const FakeCommand(
          command: <String>['codesign', '-vvv', '$flutterCache/dart-sdk/bin/dart'],
        ),
      );
      codesignCheckCommands.add(
        FakeCommand(
          command: const <String>[
            'codesign',
            '--display',
            '--entitlements',
            ':-',
            '$flutterCache/dart-sdk/bin/dart',
          ],
          stdout: expectedEntitlements.join('\n'),
        )
      );
      // Not signed
      codesignCheckCommands.add(
        const FakeCommand(
          command: <String>['codesign', '-vvv', '$flutterCache/dart-sdk/bin/dartaotruntime'],
          exitCode: 1,
        ),
      );
      codesignCheckCommands.add(
        const FakeCommand(
          command: <String>['codesign', '-vvv', '$flutterCache/engine/darwin-x64/font-subset'],
        ),
      );

      createRunner(commands: <FakeCommand>[
        const FakeCommand(command: <String>[
          'git',
          'clone',
          '--origin',
          'upstream',
          '--',
          FrameworkRepository.defaultUpstream,
          '${checkoutsParentDirectory}flutter_conductor_checkouts/framework',
        ]),
        const FakeCommand(command: <String>[
          'git',
          'checkout',
          revision,
        ]),
        const FakeCommand(command: <String>[
          'git',
          'rev-parse',
          'HEAD',
        ], stdout: revision),
        const FakeCommand(command: <String>[
          'git',
          'rev-parse',
          'HEAD',
        ], stdout: revision),
        const FakeCommand(command: <String>[
          'git',
          'checkout',
          revision,
        ]),
        const FakeCommand(command: <String>[
          flutterBin,
          'help',
        ]),
        const FakeCommand(command: <String>[
          flutterBin,
          'help',
        ]),
        const FakeCommand(command: <String>[
          flutterBin,
          'precache',
          '--android',
          '--ios',
          '--macos',
        ]),
        FakeCommand(
          command: const <String>[
            'find',
            '${checkoutsParentDirectory}flutter_conductor_checkouts/framework/bin/cache',
            '-type',
            'f',
          ],
          stdout: allBinaries.join('\n'),
        ),
        for (String bin in allBinaries)
          FakeCommand(
            command: <String>['file', '--mime-type', '-b', bin],
            stdout: 'application/x-mach-binary',
          ),
        ...codesignCheckCommands,
      ]);
      await expectLater(
        () => runner.run(<String>['codesign', '--$kVerify', '--$kRevision', revision]),
        throwsExceptionWith('Test failed because unsigned binaries detected.'),
      );
      expect(processManager.hasRemainingExpectations, false);
    });

    test('fails if a single binary has the wrong entitlements', () async {
      final List<FakeCommand> codesignCheckCommands = <FakeCommand>[];
      codesignCheckCommands.add(
        const FakeCommand(
          command: <String>['codesign', '-vvv', '$flutterCache/dart-sdk/bin/dart'],
        ),
      );
      codesignCheckCommands.add(
        FakeCommand(
          command: const <String>['codesign', '--display', '--entitlements', ':-', '$flutterCache/dart-sdk/bin/dart'],
          stdout: expectedEntitlements.join('\n'),
        )
      );
      codesignCheckCommands.add(
        const FakeCommand(
          command: <String>['codesign', '-vvv', '$flutterCache/dart-sdk/bin/dartaotruntime'],
        ),
      );
      // No entitlements
      codesignCheckCommands.add(
        const FakeCommand(
          command: <String>['codesign', '--display', '--entitlements', ':-', '$flutterCache/dart-sdk/bin/dartaotruntime'],
        )
      );
      codesignCheckCommands.add(
        const FakeCommand(
          command: <String>['codesign', '-vvv', '$flutterCache/engine/darwin-x64/font-subset'],
        ),
      );
      createRunner(commands: <FakeCommand>[
        const FakeCommand(command: <String>[
          'git',
          'clone',
          '--origin',
          'upstream',
          '--',
          FrameworkRepository.defaultUpstream,
          '${checkoutsParentDirectory}flutter_conductor_checkouts/framework',
        ]),
        const FakeCommand(command: <String>[
          'git',
          'checkout',
          revision,
        ]),
        const FakeCommand(command: <String>[
          'git',
          'rev-parse',
          'HEAD',
        ], stdout: revision),
        const FakeCommand(command: <String>[
          'git',
          'rev-parse',
          'HEAD',
        ], stdout: revision),
        const FakeCommand(command: <String>[
          'git',
          'checkout',
          revision,
        ]),
        const FakeCommand(command: <String>[
          flutterBin,
          'help',
        ]),
        const FakeCommand(command: <String>[
          flutterBin,
          'help',
        ]),
        const FakeCommand(command: <String>[
          flutterBin,
          'precache',
          '--android',
          '--ios',
          '--macos',
        ]),
        FakeCommand(
          command: const <String>[
            'find',
            '${checkoutsParentDirectory}flutter_conductor_checkouts/framework/bin/cache',
            '-type',
            'f',
          ],
          stdout: allBinaries.join('\n'),
        ),
        for (String bin in allBinaries)
          FakeCommand(
            command: <String>['file', '--mime-type', '-b', bin],
            stdout: 'application/x-mach-binary',
          ),
        ...codesignCheckCommands,
      ]);
      await expectLater(
        () => runner.run(<String>['codesign', '--$kVerify', '--$kRevision', revision]),
        throwsExceptionWith('Test failed because files found with the wrong entitlements'),
      );
      expect(processManager.hasRemainingExpectations, false);
    });

    test('does not check signatures or entitlements if --no-$kSignatures specified', () async {
      createRunner(commands: <FakeCommand>[
        const FakeCommand(command: <String>[
          'git',
          'clone',
          '--origin',
          'upstream',
          '--',
          FrameworkRepository.defaultUpstream,
          '${checkoutsParentDirectory}flutter_conductor_checkouts/framework',
        ]),
        const FakeCommand(command: <String>[
          'git',
          'checkout',
          revision,
        ]),
        const FakeCommand(command: <String>[
          'git',
          'rev-parse',
          'HEAD',
        ], stdout: revision),
        const FakeCommand(command: <String>[
          'git',
          'rev-parse',
          'HEAD',
        ], stdout: revision),
        const FakeCommand(command: <String>[
          'git',
          'checkout',
          revision,
        ]),
        const FakeCommand(command: <String>[
          flutterBin,
          'help',
        ]),
        const FakeCommand(command: <String>[
          flutterBin,
          'help',
        ]),
        const FakeCommand(command: <String>[
          flutterBin,
          'precache',
          '--android',
          '--ios',
          '--macos',
        ]),
        FakeCommand(
          command: const <String>[
            'find',
            '${checkoutsParentDirectory}flutter_conductor_checkouts/framework/bin/cache',
            '-type',
            'f',
          ],
          stdout: allBinaries.join('\n'),
        ),
        for (String bin in allBinaries)
          FakeCommand(
            command: <String>['file', '--mime-type', '-b', bin],
            stdout: 'application/x-mach-binary',
          ),
      ]);
      await runner.run(<String>[
        'codesign',
        '--$kVerify',
        '--no-$kSignatures',
        '--$kRevision',
        revision,
      ]);
      expect(
        processManager.hasRemainingExpectations,
        false,
      );
    });
  });
}

class FakeCodesignCommand extends CodesignCommand {
  FakeCodesignCommand({
    required super.checkouts,
    required this.binariesWithEntitlementsOverride,
    required this.binariesWithoutEntitlementsOverride,
    required super.flutterRoot,
  });

  final List<String> binariesWithEntitlementsOverride;
  final List<String> binariesWithoutEntitlementsOverride;

  @override
  List<String> binariesWithEntitlements(String cacheDirectoryPath) => binariesWithEntitlementsOverride;

  @override
  List<String> binariesWithoutEntitlements(String cacheDirectoryPath) => binariesWithoutEntitlementsOverride;
}
