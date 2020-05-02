// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';

class TestIcon extends StatefulWidget {
  const TestIcon({Key key}) : super(key: key);

  @override
  TestIconState createState() => TestIconState();
}

class TestIconState extends State<TestIcon> {
  IconThemeData iconTheme;

  @override
  Widget build(BuildContext context) {
    iconTheme = IconTheme.of(context);
    return const Icon(Icons.expand_more);
  }
}

class TestText extends StatefulWidget {
  const TestText(this.text, {Key key}) : super(key: key);

  final String text;

  @override
  TestTextState createState() => TestTextState();
}

class TestTextState extends State<TestText> {
  TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    textStyle = DefaultTextStyle.of(context).style;
    return Text(widget.text);
  }
}

void main() {
  const Color _dividerColor = Color(0x1f333333);
  const Color _accentColor = Colors.blueAccent;
  const Color _unselectedWidgetColor = Colors.black54;
  const Color _headerColor = Colors.black45;

  testWidgets('ExpansionTile initial state', (WidgetTester tester) async {
    final Key topKey = UniqueKey();
    const Key expandedKey = PageStorageKey<String>('expanded');
    const Key collapsedKey = PageStorageKey<String>('collapsed');
    const Key defaultKey = PageStorageKey<String>('default');

    final Key tileKey = UniqueKey();

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        dividerColor: _dividerColor,
      ),
      home: Material(
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              ListTile(title: const Text('Top'), key: topKey),
              ExpansionTile(
                key: expandedKey,
                initiallyExpanded: true,
                title: const Text('Expanded'),
                backgroundColor: Colors.red,
                children: <Widget>[
                  ListTile(
                    key: tileKey,
                    title: const Text('0'),
                  ),
                ],
              ),
              ExpansionTile(
                key: collapsedKey,
                initiallyExpanded: false,
                title: const Text('Collapsed'),
                children: <Widget>[
                  ListTile(
                    key: tileKey,
                    title: const Text('0'),
                  ),
                ],
              ),
              const ExpansionTile(
                key: defaultKey,
                title: Text('Default'),
                children: <Widget>[
                  ListTile(title: Text('0')),
                ],
              ),
            ],
          ),
        ),
      ),
    ));

    double getHeight(Key key) => tester.getSize(find.byKey(key)).height;
    Container getContainer(Key key) => tester.firstWidget(find.descendant(
      of: find.byKey(key),
      matching: find.byType(Container),
    ));

    expect(getHeight(topKey), getHeight(expandedKey) - getHeight(tileKey) - 2.0);
    expect(getHeight(topKey), getHeight(collapsedKey) - 2.0);
    expect(getHeight(topKey), getHeight(defaultKey) - 2.0);

    BoxDecoration expandedContainerDecoration = getContainer(expandedKey).decoration as BoxDecoration;
    expect(expandedContainerDecoration.color, Colors.red);
    expect(expandedContainerDecoration.border.top.color, _dividerColor);
    expect(expandedContainerDecoration.border.bottom.color, _dividerColor);

    BoxDecoration collapsedContainerDecoration = getContainer(collapsedKey).decoration as BoxDecoration;
    expect(collapsedContainerDecoration.color, Colors.transparent);
    expect(collapsedContainerDecoration.border.top.color, Colors.transparent);
    expect(collapsedContainerDecoration.border.bottom.color, Colors.transparent);

    await tester.tap(find.text('Expanded'));
    await tester.tap(find.text('Collapsed'));
    await tester.tap(find.text('Default'));

    await tester.pump();

    // Pump to the middle of the animation for expansion.
    await tester.pump(const Duration(milliseconds: 100));
    final BoxDecoration collapsingContainerDecoration = getContainer(collapsedKey).decoration as BoxDecoration;
    expect(collapsingContainerDecoration.color, Colors.transparent);
    // Opacity should change but color component should remain the same.
    expect(collapsingContainerDecoration.border.top.color, const Color(0x15333333));
    expect(collapsingContainerDecoration.border.bottom.color, const Color(0x15333333));

    // Pump all the way to the end now.
    await tester.pump(const Duration(seconds: 1));

    expect(getHeight(topKey), getHeight(expandedKey) - 2.0);
    expect(getHeight(topKey), getHeight(collapsedKey) - getHeight(tileKey) - 2.0);
    expect(getHeight(topKey), getHeight(defaultKey) - getHeight(tileKey) - 2.0);

    // Expanded should be collapsed now.
    expandedContainerDecoration = getContainer(expandedKey).decoration as BoxDecoration;
    expect(expandedContainerDecoration.color, Colors.transparent);
    expect(expandedContainerDecoration.border.top.color, Colors.transparent);
    expect(expandedContainerDecoration.border.bottom.color, Colors.transparent);

    // Collapsed should be expanded now.
    collapsedContainerDecoration = getContainer(collapsedKey).decoration as BoxDecoration;
    expect(collapsedContainerDecoration.color, Colors.transparent);
    expect(collapsedContainerDecoration.border.top.color, _dividerColor);
    expect(collapsedContainerDecoration.border.bottom.color, _dividerColor);
  }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS,  TargetPlatform.macOS }));

  testWidgets('ListTileTheme', (WidgetTester tester) async {
    final Key expandedTitleKey = UniqueKey();
    final Key collapsedTitleKey = UniqueKey();
    final Key expandedIconKey = UniqueKey();
    final Key collapsedIconKey = UniqueKey();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          accentColor: _accentColor,
          unselectedWidgetColor: _unselectedWidgetColor,
          textTheme: const TextTheme(subtitle1: TextStyle(color: _headerColor)),
        ),
        home: Material(
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                const ListTile(title: Text('Top')),
                ExpansionTile(
                  initiallyExpanded: true,
                  title: TestText('Expanded', key: expandedTitleKey),
                  backgroundColor: Colors.red,
                  children: const <Widget>[ListTile(title: Text('0'))],
                  trailing: TestIcon(key: expandedIconKey),
                ),
                ExpansionTile(
                  initiallyExpanded: false,
                  title: TestText('Collapsed', key: collapsedTitleKey),
                  children: const <Widget>[ListTile(title: Text('0'))],
                  trailing: TestIcon(key: collapsedIconKey),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Color iconColor(Key key) => tester.state<TestIconState>(find.byKey(key)).iconTheme.color;
    Color textColor(Key key) => tester.state<TestTextState>(find.byKey(key)).textStyle.color;

    expect(textColor(expandedTitleKey), _accentColor);
    expect(textColor(collapsedTitleKey), _headerColor);
    expect(iconColor(expandedIconKey), _accentColor);
    expect(iconColor(collapsedIconKey), _unselectedWidgetColor);

    // Tap both tiles to change their state: collapse and extend respectively
    await tester.tap(find.text('Expanded'));
    await tester.tap(find.text('Collapsed'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(textColor(expandedTitleKey), _headerColor);
    expect(textColor(collapsedTitleKey), _accentColor);
    expect(iconColor(expandedIconKey), _unselectedWidgetColor);
    expect(iconColor(collapsedIconKey), _accentColor);
  }, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.iOS,  TargetPlatform.macOS }));

  testWidgets('ExpansionTile subtitle', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ExpansionTile(
            title: Text('Title'),
            subtitle: Text('Subtitle'),
            children: <Widget>[ListTile(title: Text('0'))],
          ),
        ),
      ),
    );

    expect(find.text('Subtitle'), findsOneWidget);
  });

  testWidgets('ExpansionTile padding test', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Material(
        child: Center(
          child: ExpansionTile(
            title: Text('Hello'),
            tilePadding: EdgeInsets.fromLTRB(8, 12, 4, 10),
          ),
        ),
      ),
    ));

    final Rect titleRect = tester.getRect(find.text('Hello'));
    final Rect trailingRect = tester.getRect(find.byIcon(Icons.expand_more));
    final Rect listTileRect = tester.getRect(find.byType(ListTile));
    final Rect tallerWidget = titleRect.height > trailingRect.height ? titleRect : trailingRect;

    // Check the positions of title and trailing Widgets, after padding is applied.
    expect(listTileRect.left, titleRect.left - 8);
    expect(listTileRect.right, trailingRect.right + 4);

    // Calculate the remaining height of ListTile from the default height.
    final double remainingHeight = 56 - tallerWidget.height;
    expect(listTileRect.top, tallerWidget.top - remainingHeight / 2 - 12);
    expect(listTileRect.bottom, tallerWidget.bottom + remainingHeight / 2 + 10);
  });

  testWidgets('ExpansionTile alignment test', (WidgetTester tester) async {
    const Key childKey = Key('key');
    await tester.pumpWidget(MaterialApp(
      home: Material(
        child: Center(
          child: ExpansionTile(
            title: const Text('title'),
            alignment: Alignment.centerLeft,
            children: <Widget>[
              Container(height: 100, width: 100),
              Container(height: 100, width: 80, key: childKey,)
            ],
          ),
        ),
      ),
    ));

    await tester.tap(find.text('title'));
    await tester.pumpAndSettle();

    final Rect columnRect = tester.getRect(find.byType(Column).last);
    final Rect secondChild = tester.getRect(find.byKey(childKey));

    expect(columnRect.left, 0.0);
    // The width of the Column is the maximum width of the children. The maximum
    // width being 100.0, the offset of the right edge of Column from X-axis should
    // be 100.0.
    expect(columnRect.right, 100.0);

    // The alignment doesn't define the position of the children inside the Column.
    // Considering the default value for CrossAxisAlignment is CrossAxisAlignment.center,
    // the offset of the left edge of second Container from X-axis should be greater
    // than 0.
    expect(secondChild.left, greaterThan(0.0));
    expect(secondChild.right, lessThan(100.0));
  });

  testWidgets('ExpansionTile crossAxisAlignment test', (WidgetTester tester) async {
    const Key child0Key = Key('child0');
    const Key child1Key = Key('child1');
    await tester.pumpWidget(MaterialApp(
      home: Material(
        child: Center(
          child: ExpansionTile(
            title: const Text('title'),
            alignment: Alignment.centerRight,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(height: 100, width: 100, key: child0Key,),
              Container(height: 100, width: 80, key: child1Key,)
            ],
          ),
        ),
      ),
    ));

    await tester.tap(find.text('title'));
    await tester.pumpAndSettle();

    final Rect columnRect = tester.getRect(find.byType(Column).last);
    final Rect child0Rect = tester.getRect(find.byKey(child0Key));
    final Rect child1Rect = tester.getRect(find.byKey(child1Key));

    expect(columnRect.right, 800.0);
    // The width of the Column is the maximum width of the children. The maximum
    // width being 100.0, the offset of the left edge of Column from X-axis should
    // be 700.0.
    expect(columnRect.left, 700.0);

    // Considering the value of CrossAxisAlignment is CrossAxisAlignment.start,
    // the offset of the left edge of both the children from X-axis should be 700.0.
    expect(child0Rect.left, 700.0);
    expect(child1Rect.left, 700.0);
  });

  test('ExpansionTile alignment can not be null', () {
    try{
       MaterialApp(
        home: Material(
          child: ExpansionTile(
            title: const Text('title'),
            alignment: null,
          ),
        ),
      );
    } on AssertionError catch (error) {
      expect(error.toString(), contains('alignment != null'));
      expect(error.toString(), contains('is not true'));
      return;
    }
    fail('ExpansionTile did not throw AssertionError when alignment was null');
  });

  test('ExpansionTile crossAxisAlignment can not be null', () {
    try{
      MaterialApp(
        home: Material(
          child: ExpansionTile(
            title: const Text('title'),
            crossAxisAlignment: null,
          ),
        ),
      );
    } on AssertionError catch (error) {
      expect(error.toString(), contains('crossAxisAlignment != null'));
      expect(error.toString(), contains('is not true'));
      return;
    }
    fail('ExpansionTile did not throw AssertionError when crossAxisAlignment was null');
  });

  testWidgets('ExpansionTile crossAxisAlignment.baseline', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Material(
        child: ExpansionTile(
          initiallyExpanded: true,
          title: const Text('title'),
          crossAxisAlignment: CrossAxisAlignment.baseline,
          children: <Widget>[
             Container(height: 100, width: 100,),
          ],
        ),
      ),
    ));

    // When the value of crossAxisAlignment is CrossAxisAlignment.baseline,
    // the textBaseline can not be null.
    expect(tester.takeException(), isAssertionError);
  });

}
