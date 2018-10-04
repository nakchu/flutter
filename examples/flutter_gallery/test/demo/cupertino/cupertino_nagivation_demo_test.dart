// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gallery/demo/cupertino/cupertino_navigation_demo.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

void main() {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  testWidgets('Back button doesn\'t work on Android', (WidgetTester tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoNavigationDemo()
      ),
    );

    await tester.pageBack();
  });
  debugDefaultTargetPlatformOverride = null;
}
