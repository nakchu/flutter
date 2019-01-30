// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../rendering/mock_canvas.dart';
import 'editable_text_test.dart';

void main() {
  testWidgets('cursor has expected width and radius',
      (WidgetTester tester) async {
    await tester.pumpWidget(
        MediaQuery(data: const MediaQueryData(devicePixelRatio: 1.0),
        child: Directionality(
        textDirection: TextDirection.ltr,
        child: EditableText(
          backgroundCursorColor: Colors.grey,
          controller: controller,
          focusNode: focusNode,
          style: textStyle,
          cursorColor: cursorColor,
          cursorWidth: 10.0,
          cursorRadius: const Radius.circular(2.0),
        ))));

    final EditableText editableText =
        tester.firstWidget(find.byType(EditableText));
    expect(editableText.cursorWidth, 10.0);
    expect(editableText.cursorRadius.x, 2.0);
  });


  testWidgets('cursor layout has correct width', (WidgetTester tester) async {
    final GlobalKey<EditableTextState> editableTextKey =
        GlobalKey<EditableTextState>();

    String changedValue;
    final Widget widget = MaterialApp(
      home: RepaintBoundary(
        key: const ValueKey<int>(1),
        child: EditableText(
          backgroundCursorColor: Colors.grey,
          key: editableTextKey,
          controller: TextEditingController(),
          focusNode: FocusNode(),
          style: Typography(platform: TargetPlatform.android).black.subhead,
          cursorColor: Colors.blue,
          selectionControls: materialTextSelectionControls,
          keyboardType: TextInputType.text,
          onChanged: (String value) {
            changedValue = value;
          },
          cursorWidth: 15.0,
        ),
      ),
    );
    await tester.pumpWidget(widget);

    // Populate a fake clipboard.
    const String clipboardContent = ' ';
    SystemChannels.platform
        .setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'Clipboard.getData')
        return const <String, dynamic>{'text': clipboardContent};
      return null;
    });

    // Long-press to bring up the text editing controls.
    final Finder textFinder = find.byKey(editableTextKey);
    await tester.longPress(textFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('PASTE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(changedValue, clipboardContent);

    await expectLater(
      find.byKey(const ValueKey<int>(1)),
      matchesGoldenFile('editable_text_test.0.0.png'),
    );
  }, skip: !Platform.isLinux);

  testWidgets('cursor layout has correct radius', (WidgetTester tester) async {
    final GlobalKey<EditableTextState> editableTextKey =
        GlobalKey<EditableTextState>();

    String changedValue;
    final Widget widget = MaterialApp(
      home: RepaintBoundary(
        key: const ValueKey<int>(1),
        child: EditableText(
          backgroundCursorColor: Colors.grey,
          key: editableTextKey,
          controller: TextEditingController(),
          focusNode: FocusNode(),
          style: Typography(platform: TargetPlatform.android).black.subhead,
          cursorColor: Colors.blue,
          selectionControls: materialTextSelectionControls,
          keyboardType: TextInputType.text,
          onChanged: (String value) {
            changedValue = value;
          },
          cursorWidth: 15.0,
          cursorRadius: const Radius.circular(3.0),
        ),
      ),
    );
    await tester.pumpWidget(widget);

    // Populate a fake clipboard.
    const String clipboardContent = ' ';
    SystemChannels.platform
        .setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'Clipboard.getData')
        return const <String, dynamic>{'text': clipboardContent};
      return null;
    });

    // Long-press to bring up the text editing controls.
    final Finder textFinder = find.byKey(editableTextKey);
    await tester.longPress(textFinder);
    await tester.pump();

    await tester.tap(find.text('PASTE'));
    await tester.pump();

    expect(changedValue, clipboardContent);

    await expectLater(
      find.byKey(const ValueKey<int>(1)),
      matchesGoldenFile('editable_text_test.1.0.png'),
    );
  }, skip: !Platform.isLinux);

  testWidgets('Cursor animates on iOS', (WidgetTester tester) async {
    final Widget widget = MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      home: const Material(
        child: TextField(
          maxLines: 3,
        ),
      ),
    );
    await tester.pumpWidget(widget);

    await tester.tap(find.byType(TextField));
    await tester.pump();

    final EditableTextState editableTextState = tester.firstState(find.byType(EditableText));
    final RenderEditable renderEditable = editableTextState.renderEditable;

    expect(renderEditable.cursorColor.alpha, 255);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(renderEditable.cursorColor.alpha, 255);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(renderEditable.cursorColor.alpha, 110);

    await tester.pump(const Duration(milliseconds: 100));

    expect(renderEditable.cursorColor.alpha, 16);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(renderEditable.cursorColor.alpha, 0);
  });

  testWidgets('Cursor does not animate on Android', (WidgetTester tester) async {
    final Widget widget = MaterialApp(
      home: const Material(
        child: TextField(
          maxLines: 3,
        ),
      ),
    );
    await tester.pumpWidget(widget);

    await tester.tap(find.byType(TextField));
    await tester.pump();

    final EditableTextState editableTextState = tester.firstState(find.byType(EditableText));
    final RenderEditable renderEditable = editableTextState.renderEditable;

    expect(renderEditable.cursorColor.alpha, 255);

    await tester.pump(const Duration(milliseconds: 100));
    expect(renderEditable.cursorColor.alpha, 255);

    await tester.pump(const Duration(milliseconds: 100));
    expect(renderEditable.cursorColor.alpha, 255);

    await tester.pump(const Duration(milliseconds: 100));
    expect(renderEditable.cursorColor.alpha, 255);

    await tester.pump(const Duration(milliseconds: 100));
    expect(renderEditable.cursorColor.alpha, 255);

    await tester.pump(const Duration(milliseconds: 100));
    expect(renderEditable.cursorColor.alpha, 0);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(renderEditable.cursorColor.alpha, 0);
  });

  testWidgets('Cursor radius is 2.0 on iOS', (WidgetTester tester) async {
    final Widget widget = MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      home: const Material(
        child: TextField(
          maxLines: 3,
        ),
      ),
    );
    await tester.pumpWidget(widget);

    final EditableTextState editableTextState = tester.firstState(find.byType(EditableText));
    final RenderEditable renderEditable = editableTextState.renderEditable;

    expect(renderEditable.cursorRadius, const Radius.circular(2.0));
  });

  testWidgets('Cursor gets placed correctly after going out of bounds', (WidgetTester tester) async {
    const String text = 'hello world this is fun and cool and awesome!';
    controller.text = text;
    final FocusNode focusNode = FocusNode();

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 1),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: FocusScope(
            node: focusScopeNode,
            autofocus: true,
            child: EditableText(
              backgroundCursorColor: Colors.grey,
              controller: controller,
              focusNode: focusNode,
              style: textStyle,
              cursorColor: cursorColor,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(EditableText));
    final RenderEditable renderEditable = findRenderEditable(tester);
    renderEditable.selection = const TextSelection(baseOffset: 29, extentOffset: 29);

    expect(controller.selection.baseOffset, 29);

    final EditableTextState editableTextState = tester.firstState(find.byType(EditableText));
    editableTextState.updateFloatingCursor(RawFloatingCursorPoint(state: FloatingCursorDragState.Start));

    expect(controller.selection.baseOffset, 29);

    // Sets the origin.
    editableTextState.updateFloatingCursor(RawFloatingCursorPoint(state: FloatingCursorDragState.Update,
        offset: const Offset(20, 20)));

    expect(controller.selection.baseOffset, 29);

    // Moves the cursor super far right
    editableTextState.updateFloatingCursor(RawFloatingCursorPoint(state: FloatingCursorDragState.Update,
        offset: const Offset(2090, 20)));
    editableTextState.updateFloatingCursor(RawFloatingCursorPoint(state: FloatingCursorDragState.Update,
        offset: const Offset(2100, 20)));
    editableTextState.updateFloatingCursor(RawFloatingCursorPoint(state: FloatingCursorDragState.Update,
        offset: const Offset(2090, 20)));

    // After peaking the cursor, we move in the opposite direction.
    editableTextState.updateFloatingCursor(RawFloatingCursorPoint(state: FloatingCursorDragState.Update,
        offset: const Offset(1400, 20)));

    editableTextState.updateFloatingCursor(RawFloatingCursorPoint(state: FloatingCursorDragState.End));

    await tester.pumpAndSettle();
    // The cursor has been set.
    expect(controller.selection.baseOffset, 8);

    // Go in the other direction.
    editableTextState.updateFloatingCursor(RawFloatingCursorPoint(state: FloatingCursorDragState.Start));
    // Sets the origin.
    editableTextState.updateFloatingCursor(RawFloatingCursorPoint(state: FloatingCursorDragState.Update,
        offset: const Offset(20, 20)));

    editableTextState.updateFloatingCursor(RawFloatingCursorPoint(state: FloatingCursorDragState.Update,
        offset: const Offset(-5000, 20)));
    editableTextState.updateFloatingCursor(RawFloatingCursorPoint(state: FloatingCursorDragState.Update,
        offset: const Offset(-5010, 20)));
    editableTextState.updateFloatingCursor(RawFloatingCursorPoint(state: FloatingCursorDragState.Update,
        offset: const Offset(-5000, 20)));

    // Move back in the opposite direction only a few hundred.
    editableTextState.updateFloatingCursor(RawFloatingCursorPoint(state: FloatingCursorDragState.Update,
        offset: const Offset(-4850, 20)));

    editableTextState.updateFloatingCursor(RawFloatingCursorPoint(state: FloatingCursorDragState.End));

    await tester.pumpAndSettle();

    expect(controller.selection.baseOffset, 10);
  });

  testWidgets('Updating the floating cursor correctly moves the cursor', (WidgetTester tester) async {
    const String text = 'hello world this is fun and cool and awesome!';
    controller.text = text;
    final FocusNode focusNode = FocusNode();

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 1),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: FocusScope(
            node: focusScopeNode,
            autofocus: true,
            child: EditableText(
              backgroundCursorColor: Colors.grey,
              controller: controller,
              focusNode: focusNode,
              style: textStyle,
              cursorColor: cursorColor,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(EditableText));
    final RenderEditable renderEditable = findRenderEditable(tester);
    renderEditable.selection = const TextSelection(baseOffset: 29, extentOffset: 29);

    expect(controller.selection.baseOffset, 29);

    final EditableTextState editableTextState = tester.firstState(find.byType(EditableText));
    editableTextState.updateFloatingCursor(RawFloatingCursorPoint(state: FloatingCursorDragState.Start));

    expect(controller.selection.baseOffset, 29);

    // Sets the origin.
    editableTextState.updateFloatingCursor(RawFloatingCursorPoint(state: FloatingCursorDragState.Update,
      offset: const Offset(20, 20)));

    expect(controller.selection.baseOffset, 29);

    // Moves the cursor right a few characters.
    editableTextState.updateFloatingCursor(RawFloatingCursorPoint(state: FloatingCursorDragState.Update,
      offset: const Offset(-250, 20)));

    // But we have not yet set the offset because the user is not done placing the cursor.
    expect(controller.selection.baseOffset, 29);

    editableTextState.updateFloatingCursor(RawFloatingCursorPoint(state: FloatingCursorDragState.End));

    await tester.pumpAndSettle();
    // The cursor has been set.
    expect(controller.selection.baseOffset, 10);
  });

  testWidgets('autofocus sets cursor to the end of text',
      (WidgetTester tester) async {
    const String text = 'hello world';
    final FocusScopeNode focusScopeNode = FocusScopeNode();
    final FocusNode focusNode = FocusNode();

    controller.text = text;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 1.0),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: FocusScope(
            node: focusScopeNode,
            autofocus: true,
            child: EditableText(
              backgroundCursorColor: Colors.grey,
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              style: textStyle,
              cursorColor: cursorColor,
            ),
          ),
        ),
      ),
    );

    expect(focusNode.hasFocus, true);
    expect(controller.selection.isCollapsed, true);
    expect(controller.selection.baseOffset, text.length);
  });

  testWidgets('Floating cursor is painted', (WidgetTester tester) async {
    const String text = 'hello world this is fun and cool and awesome!';
    controller.text = text;
    final FocusNode focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Padding(
          padding: const EdgeInsets.only(top: 0.25),
          child: Material(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: textStyle,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(EditableText));
    final RenderEditable editable = findRenderEditable(tester);
    editable.selection = const TextSelection(baseOffset: 29, extentOffset: 29);

    final EditableTextState editableTextState = tester.firstState(find.byType(EditableText));
    editableTextState.updateFloatingCursor(RawFloatingCursorPoint(state: FloatingCursorDragState.Start));
    editableTextState.updateFloatingCursor(RawFloatingCursorPoint(state: FloatingCursorDragState.Update,
      offset: const Offset(20, 20)));
    await tester.pump();

    expect(editable, paints
      ..rrect(
        rrect: RRect.fromRectAndRadius(
          Rect.fromLTRB(464.6666564941406, 2.0833332538604736, 466.6666564941406, 14.083333015441895),
          const Radius.circular(2.0),
        ),
        color: const Color(0xff8e8e93))
      ..rrect(
        rrect: RRect.fromRectAndRadius(
          Rect.fromLTRB(465.1666564941406, 1.0833336114883423, 468.1666564941406, 15.083333969116211),
          const Radius.circular(1.0),
        ),
        color: const Color(0xbf2196f3))
    );

    // Moves the cursor right a few characters.
    editableTextState.updateFloatingCursor(
        RawFloatingCursorPoint(
          state: FloatingCursorDragState.Update,
          offset: const Offset(-250, 20)));

    expect(find.byType(EditableText), paints
      ..rrect(
        rrect: RRect.fromRectAndRadius(
          Rect.fromLTRB(192.6666717529297, 2.0833332538604736, 194.6666717529297, 14.083333015441895),
          const Radius.circular(2.0),
        ),
        color: const Color(0xff8e8e93))
      ..rrect(
        rrect: RRect.fromRectAndRadius(
          Rect.fromLTRB(195.16665649414062, 1.0833336114883423, 198.16665649414062, 15.083333969116211),
          const Radius.circular(1.0),
        ),
        color: const Color(0xbf2196f3))
    );

    editableTextState.updateFloatingCursor(RawFloatingCursorPoint(state: FloatingCursorDragState.End));

    await tester.pumpAndSettle();
  });
}
