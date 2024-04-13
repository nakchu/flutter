// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_api_samples/widgets/implicit_animations/animated_fractionally_sized_box.0.dart'
    as example;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'AnimatedFractionallySizedBox animates on tap',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const example.AnimatedFractionallySizedBoxExampleApp(),
      );

      FractionallySizedBox fractionallySizedBox = tester.widget(
        find.descendant(
          of: find.byType(AnimatedFractionallySizedBox),
          matching: find.byType(FractionallySizedBox),
        ),
      );
      expect(fractionallySizedBox.widthFactor, 0.75);
      expect(fractionallySizedBox.heightFactor, 0.25);
      expect(fractionallySizedBox.alignment, Alignment.bottomRight);

      await tester.tap(find.byType(FractionallySizedBox));
      await tester.pump();

      fractionallySizedBox = tester.widget(
        find.descendant(
          of: find.byType(AnimatedFractionallySizedBox),
          matching: find.byType(FractionallySizedBox),
        ),
      );
      expect(fractionallySizedBox.widthFactor, 0.75);
      expect(fractionallySizedBox.heightFactor, 0.25);
      expect(fractionallySizedBox.alignment, Alignment.bottomRight);

      // Advance animation to the end by the 1-second duration specified in
      // the example app.
      await tester.pump(const Duration(seconds: 1));

      fractionallySizedBox = tester.widget(
        find.descendant(
          of: find.byType(AnimatedFractionallySizedBox),
          matching: find.byType(FractionallySizedBox),
        ),
      );
      expect(fractionallySizedBox.widthFactor, 0.25);
      expect(fractionallySizedBox.heightFactor, 0.75);
      expect(fractionallySizedBox.alignment, Alignment.topLeft);
    },
  );
}
