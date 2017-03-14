// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/services.dart';
import 'package:test/test.dart';

void main() {
  test('System sound control test', () async {
    final List<MethodCall> log = <MethodCall>[];
  
    flutterPlatformChannel.setMockMethodCallHandler((MethodCall methodCall) async {
      log.add(methodCall);
    });
  
    await SystemSound.play(SystemSoundType.click);

    expect(log, equals(<MethodCall>[new MethodCall('SystemSound.play', "SystemSoundType.click")]));
  });
}
