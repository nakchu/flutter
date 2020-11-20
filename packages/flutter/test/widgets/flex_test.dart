// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

void main() {
  testWidgets('Can hit test flex children of stacks', (WidgetTester tester) async {
    bool didReceiveTap = false;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          color: const Color(0xFF00FF00),
          child: Stack(
            children: <Widget>[
              Positioned(
                top: 10.0,
                left: 10.0,
                child: Column(
                  children: <Widget>[
                    GestureDetector(
                      onTap: () {
                        didReceiveTap = true;
                      },
                      child: Container(
                        color: const Color(0xFF0000FF),
                        width: 100.0,
                        height: 100.0,
                        child: const Center(
                          child: Text('X', textDirection: TextDirection.ltr),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('X'));
    expect(didReceiveTap, isTrue);
  });

  testWidgets('Flexible defaults to loose', (WidgetTester tester) async {
    await tester.pumpWidget(
      Row(
        textDirection: TextDirection.ltr,
        children: const <Widget>[
          Flexible(child: SizedBox(width: 100.0, height: 200.0)),
        ],
      ),
    );

    final RenderBox box = tester.renderObject(find.byType(SizedBox));
    expect(box.size.width, 100.0);
  });

  testWidgets("Doesn't overflow because of floating point accumulated error", (WidgetTester tester) async {
    // both of these cases have failed in the past due to floating point issues
    await tester.pumpWidget(
      Center(
        child: Container(
          height: 400.0,
          child: Column(
            children: <Widget>[
              Expanded(child: Container()),
              Expanded(child: Container()),
              Expanded(child: Container()),
              Expanded(child: Container()),
              Expanded(child: Container()),
              Expanded(child: Container()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      Center(
        child: Container(
          height: 199.0,
          child: Column(
            children: <Widget>[
              Expanded(child: Container()),
              Expanded(child: Container()),
              Expanded(child: Container()),
              Expanded(child: Container()),
              Expanded(child: Container()),
              Expanded(child: Container()),
            ],
          ),
        ),
      ),
    );
  });

  testWidgets('Error information is printed correctly', (WidgetTester tester) async {
    // We run this twice, the first time without an error, so that the second time
    // we only get a single exception. Otherwise we'd get two, the one we want and
    // an extra one when we discover we never computed a size.
    await tester.pumpWidget(
      Column(
        children: <Widget>[
          Column(),
        ],
      ),
      Duration.zero,
      EnginePhase.layout,
    );
    await tester.pumpWidget(
      Column(
        children: <Widget>[
          Column(
            children: <Widget>[
              Expanded(child: Container()),
            ],
          ),
        ],
      ),
      Duration.zero,
      EnginePhase.layout,
    );
    final String message = tester.takeException().toString();
    expect(message, contains('\nSee also:'));
  });

  testWidgets('Can set and update clipBehavior', (WidgetTester tester) async {
    await tester.pumpWidget(Flex(direction: Axis.vertical));
    final RenderFlex renderObject = tester.allRenderObjects.whereType<RenderFlex>().first;
    expect(renderObject.clipBehavior, equals(Clip.none));

    await tester.pumpWidget(Flex(direction: Axis.vertical, clipBehavior: Clip.antiAlias));
    expect(renderObject.clipBehavior, equals(Clip.antiAlias));
  });

  testWidgets('Flex to fill min extent - horizontal', (WidgetTester tester) async {
    await tester.pumpWidget(
      Center(
        child: OverflowBox(
          minWidth: 200,
          maxWidth: double.infinity,
          child: Flex(
            direction: Axis.horizontal,
            textDirection: TextDirection.ltr,
            children: const <Widget>[
              Flexible(child: SizedBox.expand()),
              SizedBox(width: 50.0, height: 200.0)
            ],
          ),
        ),
      ),
    );

    final RenderBox flexible = tester.renderObject(find.byType(Flexible));
    expect(flexible.size.width, 200.0 - 50.0);

    final RenderBox flex = tester.renderObject(find.byType(Flex));
    expect(flex.size.width, 200.0);
  });

  testWidgets('Flex to fill min extent - vertically', (WidgetTester tester) async {
    await tester.pumpWidget(
      Center(
        child: OverflowBox(
          minHeight: 200,
          maxHeight: double.infinity,
          child: Flex(
            direction: Axis.vertical,
            textDirection: TextDirection.ltr,
            children: const <Widget>[
              Flexible(child: SizedBox.expand()),
              SizedBox(width: 50.0, height: 50.0)
            ],
          ),
        ),
      ),
    );

    final RenderBox flexible = tester.renderObject(find.byType(Flexible));
    expect(flexible.size.height, 200.0 - 50.0);

    final RenderBox flex = tester.renderObject(find.byType(Flex));
    expect(flex.size.height, 200.0);
  });
}
