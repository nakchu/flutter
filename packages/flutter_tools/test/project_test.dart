// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:flutter_tools/src/flutter_manifest.dart';
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:test/test.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';

import 'src/context.dart';

void main() {
  group('Project', () {
    testInMemory('knows location', () async {
      final Directory directory = fs.directory('myproject');
      expect(
        (await FlutterProject.fromDirectory(directory)).directory.absolute.path,
        directory.absolute.path,
      );
      expect(
        (await FlutterProject.fromPath(directory.path)).directory.absolute.path,
        directory.absolute.path,
      );
      expect(
        (await FlutterProject.current()).directory.absolute.path,
        fs.currentDirectory.absolute.path,
      );
    });
    
    group('ensure ready for platform-specific tooling', () {
      testInMemory('does nothing, if project is not created', () async {
        final FlutterProject project = someProject();
        await project.ensureReadyForPlatformSpecificTooling();
        expect(project.directory.existsSync(), isFalse);
      });
      testInMemory('does nothing in plugin or package root project', () async {
        final FlutterProject project = aPluginProject();
        await project.ensureReadyForPlatformSpecificTooling();
        expect(project.ios.directory.childFile('Runner/GeneratedPluginRegistrant.h').existsSync(), isFalse);
        expect(project.ios.directory.childFile('Flutter/Generated.xcconfig').existsSync(), isFalse);
      });
      testInMemory('injects plugins', () async {
        final FlutterProject project = aProjectWithIos();
        await project.ensureReadyForPlatformSpecificTooling();
        expect(project.ios.directory.childFile('Runner/GeneratedPluginRegistrant.h').existsSync(), isTrue);
      });
      testInMemory('generates Xcode configuration', () async {
        final FlutterProject project = aProjectWithIos();
        await project.ensureReadyForPlatformSpecificTooling();
        expect(project.ios.directory.childFile('Flutter/Generated.xcconfig').existsSync(), isTrue);
      });
    });

    group('module status', () {
      testInMemory('is known for module', () async {
        final FlutterProject project = aModuleProject();
        expect(project.isModule, isTrue);
      });
      testInMemory('is known for non-module', () async {
        final FlutterProject project = someProject();
        expect(project.isModule, isFalse);
      });
    });

    group('example', () {
      testInMemory('exists for plugin', () async {
        final FlutterProject project = aPluginProject();
        expect(project.hasExampleApp, isTrue);
      });
      testInMemory('does not exist for non-plugin', () async {
        final FlutterProject project = someProject();
        expect(project.hasExampleApp, isFalse);
      });
    });

    group('organization names set', () {
      testInMemory('is empty, if project not created', () async {
        final FlutterProject project = someProject();
        expect(await project.organizationNames(), isEmpty);
      });
      testInMemory('is empty, if no platform folders exist', () async {
        final FlutterProject project = someProject();
        project.directory.createSync();
        expect(await project.organizationNames(), isEmpty);
      });
      testInMemory('is populated from iOS bundle identifier', () async {
        final FlutterProject project = someProject();
        addIosWithBundleId(project.directory, 'io.flutter.someProject');
        expect(await project.organizationNames(), <String>['io.flutter']);
      });
      testInMemory('is populated from Android application ID', () async {
        final FlutterProject project = someProject();
        addAndroidWithApplicationId(project.directory, 'io.flutter.someproject');
        expect(await project.organizationNames(), <String>['io.flutter']);
      });
      testInMemory('is populated from iOS bundle identifier in plugin example', () async {
        final FlutterProject project = someProject();
        addIosWithBundleId(project.example.directory, 'io.flutter.someProject');
        expect(await project.organizationNames(), <String>['io.flutter']);
      });
      testInMemory('is populated from Android application ID in plugin example', () async {
        final FlutterProject project = someProject();
        addAndroidWithApplicationId(project.example.directory, 'io.flutter.someproject');
        expect(await project.organizationNames(), <String>['io.flutter']);
      });
      testInMemory('is populated from Android group in plugin', () async {
        final FlutterProject project = someProject();
        addAndroidWithGroup(project.directory, 'io.flutter.someproject');
        expect(await project.organizationNames(), <String>['io.flutter']);
      });
      testInMemory('is singleton, if sources agree', () async {
        final FlutterProject project = someProject();
        addIosWithBundleId(project.directory, 'io.flutter.someProject');
        addAndroidWithApplicationId(project.directory, 'io.flutter.someproject');
        expect(await project.organizationNames(), <String>['io.flutter']);
      });
      testInMemory('is non-singleton, if sources disagree', () async {
        final FlutterProject project = someProject();
        addIosWithBundleId(project.directory, 'io.flutter.someProject');
        addAndroidWithApplicationId(project.directory, 'io.clutter.someproject');
        expect(
          await project.organizationNames(),
          <String>['io.flutter', 'io.clutter'],
        );
      });
    });
  });
}

FlutterProject someProject() => new FlutterProject(
  fs.directory('some_project'),
  FlutterManifest.empty(),
  FlutterManifest.empty(),
);

FlutterProject aProjectWithIos() {
  final Directory directory = fs.directory('ios_project');
  directory.childFile('.packages').createSync(recursive: true);
  directory.childDirectory('ios').createSync(recursive: true);
  return new FlutterProject(directory, FlutterManifest.empty(), FlutterManifest.empty());
}

FlutterProject aPluginProject() {
  final Directory directory = fs.directory('plugin_project/example');
  directory.createSync(recursive: true);
  return new FlutterProject(
    directory.parent,
    FlutterManifest.mock(const <String, dynamic>{
      'flutter': <String, dynamic>{
        'plugin': <String, dynamic>{}
      }
    }),
    FlutterManifest.empty(),
  );
}

FlutterProject aModuleProject() {
  return new FlutterProject(
    fs.directory('module_project'),
    FlutterManifest.mock(const <String, dynamic>{
      'flutter': <String, dynamic>{
        'module': <String, dynamic>{}
      }
    }),
    FlutterManifest.empty(),
  );
}

void testInMemory(String description, Future<Null> testMethod()) {
  testUsingContext(
    description,
    testMethod,
    overrides: <Type, Generator>{
      FileSystem: () => new MemoryFileSystem(),
    },
  );
}

void addIosWithBundleId(Directory directory, String id) {
  directory
      .childDirectory('ios')
      .childDirectory('Runner.xcodeproj')
      .childFile('project.pbxproj')
        ..createSync(recursive: true)
        ..writeAsStringSync(projectFileWithBundleId(id));
}

void addAndroidWithApplicationId(Directory directory, String id) {
  directory
      .childDirectory('android')
      .childDirectory('app')
      .childFile('build.gradle')
        ..createSync(recursive: true)
        ..writeAsStringSync(gradleFileWithApplicationId(id));
}

void addAndroidWithGroup(Directory directory, String id) {
  directory.childDirectory('android').childFile('build.gradle')
    ..createSync(recursive: true)
    ..writeAsStringSync(gradleFileWithGroupId(id));
}

String projectFileWithBundleId(String id) {
  return '''
97C147061CF9000F007C117D /* Debug */ = {
  isa = XCBuildConfiguration;
  baseConfigurationReference = 9740EEB21CF90195004384FC /* Debug.xcconfig */;
  buildSettings = {
    PRODUCT_BUNDLE_IDENTIFIER = $id;
    PRODUCT_NAME = "\$(TARGET_NAME)";
  };
  name = Debug;
};
''';
}

String gradleFileWithApplicationId(String id) {
  return '''
apply plugin: 'com.android.application'
android {
    compileSdkVersion 27

    defaultConfig {
        applicationId '$id'
    }
}
''';
}

String gradleFileWithGroupId(String id) {
  return '''
group '$id'
version '1.0-SNAPSHOT'

apply plugin: 'com.android.library'

android {
    compileSdkVersion 27
}
''';
}
