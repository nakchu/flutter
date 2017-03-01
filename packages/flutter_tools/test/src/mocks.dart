// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter_tools/src/android/android_device.dart';
import 'package:flutter_tools/src/application_package.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/devfs.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/ios/devices.dart';
import 'package:flutter_tools/src/ios/simulators.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:mockito/mockito_no_mirrors.dart';
import 'package:test/test.dart';

class MockApplicationPackageStore extends ApplicationPackageStore {
  MockApplicationPackageStore() : super(
    android: new AndroidApk(
      id: 'io.flutter.android.mock',
      apkPath: '/mock/path/to/android/SkyShell.apk',
      launchActivity: 'io.flutter.android.mock.MockActivity'
    ),
    iOS: new BuildableIOSApp(
      appDirectory: '/mock/path/to/iOS/SkyShell.app',
      projectBundleId: 'io.flutter.ios.mock'
    )
  );
}

class MockAndroidDevice extends Mock implements AndroidDevice {
  @override
  TargetPlatform get platform => TargetPlatform.android_arm;

  @override
  bool isSupported() => true;
}

class MockIOSDevice extends Mock implements IOSDevice {
  @override
  TargetPlatform get platform => TargetPlatform.ios;

  @override
  bool isSupported() => true;
}

class MockIOSSimulator extends Mock implements IOSSimulator {
  @override
  TargetPlatform get platform => TargetPlatform.ios;

  @override
  bool isSupported() => true;
}

class MockDeviceLogReader extends DeviceLogReader {
  @override
  String get name => 'MockLogReader';

  final StreamController<String> _linesController = new StreamController<String>.broadcast();

  @override
  Stream<String> get logLines => _linesController.stream;

  void addLine(String line) => _linesController.add(line);

  void dispose() {
    _linesController.close();
  }
}

void applyMocksToCommand(FlutterCommand command) {
  command
    ..applicationPackages = new MockApplicationPackageStore()
    ..commandValidator = () => true;
}

/// Common functionality for tracking mock interaction
class BasicMock {
  final List<String> messages = new List<String>();

  void expectMessages(List<String> expectedMessages) {
    List<String> actualMessages = new List<String>.from(messages);
    messages.clear();
    expect(actualMessages, unorderedEquals(expectedMessages));
  }

  bool contains(String match) {
    print('Checking for `$match` in:');
    print(messages);
    bool result = messages.contains(match);
    messages.clear();
    return result;
  }
}

class MockDevFSOperations extends BasicMock implements DevFSOperations {
  Map<String, DevFSContent> devicePathToContent = <String, DevFSContent>{};

  @override
  Future<Uri> create(String fsName) async {
    messages.add('create $fsName');
    return Uri.parse('file:///$fsName');
  }

  @override
  Future<dynamic> destroy(String fsName) async {
    messages.add('destroy $fsName');
  }

  @override
  Future<dynamic> writeFile(String fsName, String devicePath, DevFSContent content) async {
    messages.add('writeFile $fsName $devicePath');
    devicePathToContent[devicePath] = content;
  }

  @override
  Future<dynamic> deleteFile(String fsName, String devicePath) async {
    messages.add('deleteFile $fsName $devicePath');
    devicePathToContent.remove(devicePath);
  }
}
