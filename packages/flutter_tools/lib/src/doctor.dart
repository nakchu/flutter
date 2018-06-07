// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'android/android_studio_validator.dart';
import 'android/android_workflow.dart';
import 'artifacts.dart';
import 'base/common.dart';
import 'base/context.dart';
import 'base/file_system.dart';
import 'base/logger.dart';
import 'base/os.dart';
import 'base/platform.dart';
import 'base/process_manager.dart';
import 'base/version.dart';
import 'cache.dart';
import 'device.dart';
import 'globals.dart';
import 'intellij/intellij.dart';
import 'ios/ios_workflow.dart';
import 'ios/plist_utils.dart';
import 'tester/flutter_tester.dart';
import 'version.dart';
import 'vscode/vscode_validator.dart';

Doctor get doctor => context[Doctor];

abstract class DoctorValidatorsProvider {
  /// The singleton instance, pulled from the [AppContext].
  static DoctorValidatorsProvider get instance => context[DoctorValidatorsProvider];

  static final DoctorValidatorsProvider defaultInstance = new _DefaultDoctorValidatorsProvider();

  List<DoctorValidator> get validators;
}

class _DefaultDoctorValidatorsProvider implements DoctorValidatorsProvider {
  List<DoctorValidator> _validators;

  @override
  List<DoctorValidator> get validators {
    if (_validators == null) {
      _validators = <DoctorValidator>[];
      _validators.add(new _FlutterValidator());

      if (androidWorkflow.appliesToHostPlatform)
        _validators.add(androidWorkflow);

      if (iosWorkflow.appliesToHostPlatform)
        _validators.add(iosWorkflow);

      final List<DoctorValidator> ideValidators = <DoctorValidator>[];
      ideValidators.addAll(AndroidStudioValidator.allValidators);
      ideValidators.addAll(IntelliJValidator.installedValidators);
      ideValidators.addAll(VsCodeValidator.installedValidators);
      if (ideValidators.isNotEmpty)
        _validators.addAll(ideValidators);
      else
        _validators.add(new NoIdeValidator());

      if (deviceManager.canListAnything)
        _validators.add(new DeviceValidator());
    }
    return _validators;
  }
}

class ValidatorTask {
  ValidatorTask(this.validator, this.result);
  final DoctorValidator validator;
  final Future<ValidationResult> result;
}

class Doctor {
  const Doctor();

  List<DoctorValidator> get validators {
    return DoctorValidatorsProvider.instance.validators;
  }

  /// Return a list of [ValidatorTask] objects and starts validation on all
  /// objects in [validators].
  List<ValidatorTask> startValidatorTasks() {
    final List<ValidatorTask> tasks = <ValidatorTask>[];
    for (DoctorValidator validator in validators) {
      tasks.add(new ValidatorTask(validator, validator.validate()));
    }
    return tasks;
  }

  List<Workflow> get workflows {
    return new List<Workflow>.from(validators.where((DoctorValidator validator) => validator is Workflow));
  }

  /// Print a summary of the state of the tooling, as well as how to get more info.
  Future<Null> summary() async {
    printStatus(await summaryText);
  }

  Future<String> get summaryText async {
    final StringBuffer buffer = new StringBuffer();

    bool allGood = true;

    for (DoctorValidator validator in validators) {
      final ValidationResult result = await validator.validate();
      buffer.write('${result.leadingBox} ${validator.title} is ');
      if (result.type == ValidationType.missing)
        buffer.write('not installed.');
      else if (result.type == ValidationType.partial)
        buffer.write('partially installed; more components are available.');
      else
        buffer.write('fully installed.');

      if (result.statusInfo != null)
        buffer.write(' (${result.statusInfo})');

      buffer.writeln();

      if (result.type != ValidationType.installed)
        allGood = false;
    }

    if (!allGood) {
      buffer.writeln();
      buffer.writeln('Run "flutter doctor" for information about installing additional components.');
    }

    return buffer.toString();
  }

  /// Print information about the state of installed tooling.
  Future<bool> diagnose({ bool androidLicenses = false, bool verbose = true }) async {
    if (androidLicenses)
      return AndroidWorkflow.runLicenseManager();

    if (!verbose) {
      printStatus('Doctor summary (to see all details, run flutter doctor -v):');
    }
    bool doctorResult = true;
    int issues = 0;

    for (ValidatorTask validatorTask in startValidatorTasks()) {
      final DoctorValidator validator = validatorTask.validator;
      final Status status = new Status.withSpinner();
      await (validatorTask.result).then<void>((_) {
        status.stop();
      }).whenComplete(status.cancel);

      final ValidationResult result = await validatorTask.result;
      if (result.type == ValidationType.missing) {
        doctorResult = false;
      }
      if (result.type != ValidationType.installed) {
        issues += 1;
      }

      if (result.statusInfo != null)
        printStatus('${result.leadingBox} ${validator.title} (${result.statusInfo})');
      else
        printStatus('${result.leadingBox} ${validator.title}');

      for (ValidationMessage message in result.messages) {
        if (message.isError || message.isHint || verbose == true) {
          final String text = message.message.replaceAll('\n', '\n      ');
          if (message.isError) {
            printStatus('    ✗ $text', emphasis: true);
          } else if (message.isHint) {
            printStatus('    ! $text');
          } else {
            printStatus('    • $text');
          }
        }
      }
      if (verbose)
        printStatus('');
    }

    // Make sure there's always one line before the summary even when not verbose.
    if (!verbose)
      printStatus('');
    if (issues > 0) {
      printStatus('! Doctor found issues in $issues categor${issues > 1 ? "ies" : "y"}.');
    } else {
      printStatus('• No issues found!');
    }

    return doctorResult;
  }

  bool get canListAnything => workflows.any((Workflow workflow) => workflow.canListDevices);

  bool get canLaunchAnything {
    if (FlutterTesterDevices.showFlutterTesterDevice)
      return true;
    return workflows.any((Workflow workflow) => workflow.canLaunchDevices);
  }
}

/// A series of tools and required install steps for a target platform (iOS or Android).
abstract class Workflow {
  /// Whether the workflow applies to this platform (as in, should we ever try and use it).
  bool get appliesToHostPlatform;

  /// Are we functional enough to list devices?
  bool get canListDevices;

  /// Could this thing launch *something*? It may still have minor issues.
  bool get canLaunchDevices;

  /// Are we functional enough to list emulators?
  bool get canListEmulators;
}

enum ValidationType {
  missing,
  partial,
  installed
}

abstract class DoctorValidator {
  const DoctorValidator(this.title);

  final String title;

  Future<ValidationResult> validate();
}


class ValidationResult {
  /// [ValidationResult.type] should only equal [ValidationResult.installed]
  /// if no [messages] are hints or errors.
  ValidationResult(this.type, this.messages, { this.statusInfo });

  final ValidationType type;
  // A short message about the status.
  final String statusInfo;
  final List<ValidationMessage> messages;

  String get leadingBox {
    assert(type != null);
    switch (type) {
      case ValidationType.missing:
        return '[✗]';
      case ValidationType.installed:
        return '[✓]';
      case ValidationType.partial:
        return '[!]';
    }
    return null;
  }
}

class ValidationMessage {
  ValidationMessage(this.message) : isError = false, isHint = false;
  ValidationMessage.error(this.message) : isError = true, isHint = false;
  ValidationMessage.hint(this.message) : isError = false, isHint = true;

  final bool isError;
  final bool isHint;
  final String message;

  @override
  String toString() => message;
}

class _FlutterValidator extends DoctorValidator {
  _FlutterValidator() : super('Flutter');

  @override
  Future<ValidationResult> validate() async {
    final List<ValidationMessage> messages = <ValidationMessage>[];
    ValidationType valid = ValidationType.installed;

    final FlutterVersion version = FlutterVersion.instance;

    messages.add(new ValidationMessage('Flutter version ${version.frameworkVersion} at ${Cache.flutterRoot}'));
    messages.add(new ValidationMessage(
      'Framework revision ${version.frameworkRevisionShort} '
      '(${version.frameworkAge}), ${version.frameworkDate}'
    ));
    messages.add(new ValidationMessage('Engine revision ${version.engineRevisionShort}'));
    messages.add(new ValidationMessage('Dart version ${version.dartSdkVersion}'));
    final String genSnapshotPath =
      artifacts.getArtifactPath(Artifact.genSnapshot);

    // Check that the binaries we downloaded for this platform actually run on it.
    if (!_genSnapshotRuns(genSnapshotPath)) {
      final StringBuffer buf = new StringBuffer();
      buf.writeln('Downloaded executables cannot execute on host.');
      buf.writeln('See https://github.com/flutter/flutter/issues/6207 for more information');
      if (platform.isLinux) {
        buf.writeln('On Debian/Ubuntu/Mint: sudo apt-get install lib32stdc++6');
        buf.writeln('On Fedora: dnf install libstdc++.i686');
        buf.writeln('On Arch: pacman -S lib32-libstdc++5');
      }
      messages.add(new ValidationMessage.error(buf.toString()));
      valid = ValidationType.partial;
    }

    return new ValidationResult(valid, messages,
      statusInfo: 'Channel ${version.channel}, v${version.frameworkVersion}, on ${os.name}, locale ${platform.localeName}'
    );
  }
}

bool _genSnapshotRuns(String genSnapshotPath) {
  const int kExpectedExitCode = 255;
  try {
    return processManager.runSync(<String>[genSnapshotPath]).exitCode == kExpectedExitCode;
  } catch (error) {
    return false;
  }
}

class NoIdeValidator extends DoctorValidator {
  NoIdeValidator() : super('Flutter IDE Support');

  @override
  Future<ValidationResult> validate() async {
    return new ValidationResult(ValidationType.missing, <ValidationMessage>[
      new ValidationMessage('IntelliJ - https://www.jetbrains.com/idea/'),
    ], statusInfo: 'No supported IDEs installed');
  }
}

abstract class IntelliJValidator extends DoctorValidator {
  final String installPath;

  IntelliJValidator(String title, this.installPath) : super(title);

  String get version;
  String get pluginsPath;

  static final Map<String, String> _idToTitle = <String, String>{
    'IntelliJIdea' : 'IntelliJ IDEA Ultimate Edition',
    'IdeaIC' : 'IntelliJ IDEA Community Edition',
  };

  static final Version kMinIdeaVersion = new Version(2017, 1, 0);

  static Iterable<DoctorValidator> get installedValidators {
    if (platform.isLinux || platform.isWindows)
      return IntelliJValidatorOnLinuxAndWindows.installed;
    if (platform.isMacOS)
      return IntelliJValidatorOnMac.installed;
    return <DoctorValidator>[];
  }

  @override
  Future<ValidationResult> validate() async {
    final List<ValidationMessage> messages = <ValidationMessage>[];

    messages.add(new ValidationMessage('IntelliJ at $installPath'));

    final IntelliJPlugins plugins = new IntelliJPlugins(pluginsPath);
    plugins.validatePackage(messages, <String>['flutter-intellij', 'flutter-intellij.jar'],
        'Flutter', minVersion: IntelliJPlugins.kMinFlutterPluginVersion);
    plugins.validatePackage(messages, <String>['Dart'], 'Dart');

    if (_hasIssues(messages)) {
      messages.add(new ValidationMessage(
        'For information about installing plugins, see\n'
        'https://flutter.io/intellij-setup/#installing-the-plugins'
      ));
    }

    _validateIntelliJVersion(messages, kMinIdeaVersion);

    return new ValidationResult(
      _hasIssues(messages) ? ValidationType.partial : ValidationType.installed,
      messages,
      statusInfo: 'version $version'
    );
  }

  bool _hasIssues(List<ValidationMessage> messages) {
    return messages.any((ValidationMessage message) => message.isError);
  }

  void _validateIntelliJVersion(List<ValidationMessage> messages, Version minVersion) {
    // Ignore unknown versions.
    if (minVersion == Version.unknown)
      return;

    final Version installedVersion = new Version.parse(version);
    if (installedVersion == null)
      return;

    if (installedVersion < minVersion) {
      messages.add(new ValidationMessage.error(
        'This install is older than the minimum recommended version of $minVersion.'
      ));
    }
  }
}

class IntelliJValidatorOnLinuxAndWindows extends IntelliJValidator {
  IntelliJValidatorOnLinuxAndWindows(String title, this.version, String installPath, this.pluginsPath) : super(title, installPath);

  @override
  final String version;

  @override
  final String pluginsPath;

  static Iterable<DoctorValidator> get installed {
    final List<DoctorValidator> validators = <DoctorValidator>[];
    if (homeDirPath == null)
      return validators;

    void addValidator(String title, String version, String installPath, String pluginsPath) {
      final IntelliJValidatorOnLinuxAndWindows validator =
        new IntelliJValidatorOnLinuxAndWindows(title, version, installPath, pluginsPath);
      for (int index = 0; index < validators.length; ++index) {
        final DoctorValidator other = validators[index];
        if (other is IntelliJValidatorOnLinuxAndWindows && validator.installPath == other.installPath) {
          if (validator.version.compareTo(other.version) > 0)
            validators[index] = validator;
          return;
        }
      }
      validators.add(validator);
    }

    for (FileSystemEntity dir in fs.directory(homeDirPath).listSync()) {
      if (dir is Directory) {
        final String name = fs.path.basename(dir.path);
        IntelliJValidator._idToTitle.forEach((String id, String title) {
          if (name.startsWith('.$id')) {
            final String version = name.substring(id.length + 1);
            String installPath;
            try {
              installPath = fs.file(fs.path.join(dir.path, 'system', '.home')).readAsStringSync();
            } catch (e) {
              // ignored
            }
            if (installPath != null && fs.isDirectorySync(installPath)) {
              final String pluginsPath = fs.path.join(dir.path, 'config', 'plugins');
              addValidator(title, version, installPath, pluginsPath);
            }
          }
        });
      }
    }
    return validators;
  }
}

class IntelliJValidatorOnMac extends IntelliJValidator {
  IntelliJValidatorOnMac(String title, this.id, String installPath) : super(title, installPath);

  final String id;

  static final Map<String, String> _dirNameToId = <String, String>{
    'IntelliJ IDEA.app' : 'IntelliJIdea',
    'IntelliJ IDEA Ultimate.app' : 'IntelliJIdea',
    'IntelliJ IDEA CE.app' : 'IdeaIC',
  };

  static Iterable<DoctorValidator> get installed {
    final List<DoctorValidator> validators = <DoctorValidator>[];
    final List<String> installPaths = <String>['/Applications', fs.path.join(homeDirPath, 'Applications')];

    void checkForIntelliJ(Directory dir) {
      final String name = fs.path.basename(dir.path);
      _dirNameToId.forEach((String dirName, String id) {
        if (name == dirName) {
          final String title = IntelliJValidator._idToTitle[id];
          validators.add(new IntelliJValidatorOnMac(title, id, dir.path));
        }
      });
    }

    try {
      final Iterable<FileSystemEntity> installDirs = installPaths
              .map((String installPath) => fs.directory(installPath))
              .map((Directory dir) => dir.existsSync() ? dir.listSync() : <FileSystemEntity>[])
              .expand((List<FileSystemEntity> mappedDirs) => mappedDirs)
              .where((FileSystemEntity mappedDir) => mappedDir is Directory);
      for (FileSystemEntity dir in installDirs) {
        if (dir is Directory) {
          checkForIntelliJ(dir);
          if (!dir.path.endsWith('.app')) {
            for (FileSystemEntity subdir in dir.listSync()) {
              if (subdir is Directory) {
                checkForIntelliJ(subdir);
              }
            }
          }
        }
      }
    } on FileSystemException catch (e) {
      validators.add(new ValidatorWithResult(
          'Cannot determine if IntelliJ is installed',
          new ValidationResult(ValidationType.missing, <ValidationMessage>[
             new ValidationMessage.error(e.message),
          ]),
      ));
    }
    return validators;
  }

  @override
  String get version {
    if (_version == null) {
      final String plistFile = fs.path.join(installPath, 'Contents', 'Info.plist');
      _version = iosWorkflow.getPlistValueFromFile(
        plistFile,
        kCFBundleShortVersionStringKey,
      ) ?? 'unknown';
    }
    return _version;
  }
  String _version;

  @override
  String get pluginsPath {
    final List<String> split = version.split('.');
    final String major = split[0];
    final String minor = split[1];
    return fs.path.join(homeDirPath, 'Library', 'Application Support', '$id$major.$minor');
  }
}

class DeviceValidator extends DoctorValidator {
  DeviceValidator() : super('Connected devices');

  @override
  Future<ValidationResult> validate() async {
    final List<Device> devices = await deviceManager.getAllConnectedDevices().toList();
    List<ValidationMessage> messages;
    if (devices.isEmpty) {
      final List<String> diagnostics = await deviceManager.getDeviceDiagnostics();
      if (diagnostics.isNotEmpty) {
        messages = diagnostics.map((String message) => new ValidationMessage(message)).toList();
      } else {
        messages = <ValidationMessage>[new ValidationMessage.hint('No devices available')];
      }
    } else {
      messages = await Device.descriptions(devices)
          .map((String msg) => new ValidationMessage(msg)).toList();
    }

    if (devices.isEmpty) {
      return new ValidationResult(ValidationType.partial, messages);
    } else {
      return new ValidationResult(ValidationType.installed, messages, statusInfo: '${devices.length} available');
    }
  }
}

class ValidatorWithResult extends DoctorValidator {
  final ValidationResult result;

  ValidatorWithResult(String title, this.result) : super(title);

  @override
  Future<ValidationResult> validate() async => result;
}
