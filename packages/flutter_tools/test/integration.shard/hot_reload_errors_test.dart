// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';

import '../src/common.dart';
import 'test_data/hot_reload_const_project.dart';
import 'test_driver.dart';
import 'test_utils.dart';

void main() {
  Directory tempDir;
  final HotReloadConstProject project = HotReloadConstProject();
  FlutterRunTestDriver flutter;

  setUp(() async {
    tempDir = createResolvedTempDirectorySync('hot_reload_test.');
    await project.setUpIn(tempDir);
    flutter = FlutterRunTestDriver(tempDir);
  });

  tearDown(() async {
    await flutter?.stop();
    tryToDelete(tempDir);
  });

  testWithoutContext('hot reload displays a pretty, actionable error message when removing a field from a const class', () async {
    await flutter.run();
    project.removeFieldFromConstClass();

    expect(flutter.hotReload(), throwsA(contains('Try performing a hot restart instead.')));
  });
}
