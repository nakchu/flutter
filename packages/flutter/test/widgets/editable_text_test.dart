// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

void main() {
  final TextEditingController controller = new TextEditingController();
  final FocusNode focusNode = new FocusNode();
  final FocusScopeNode focusScopeNode = new FocusScopeNode();
  final TextStyle textStyle = const TextStyle();
  final Color cursorColor = const Color.fromARGB(0xFF, 0xFF, 0x00, 0x00);

  testWidgets('has expected defaults', (WidgetTester tester) async {
    await tester.pumpWidget(new Directionality(
        textDirection: TextDirection.ltr,
        child: new EditableText(
          controller: controller,
          focusNode: focusNode,
          style: textStyle,
          cursorColor: cursorColor,
        )));

    final EditableText editableText =
        tester.firstWidget(find.byType(EditableText));
    expect(editableText.maxLines, equals(1));
    expect(editableText.obscureText, isFalse);
    expect(editableText.autocorrect, isTrue);
  });

  testWidgets('text keyboard is requested when maxLines is default',
      (WidgetTester tester) async {
    await tester.pumpWidget(new Directionality(
        textDirection: TextDirection.ltr,
        child: new FocusScope(
            node: focusScopeNode,
            autofocus: true,
            child: new EditableText(
              controller: controller,
              focusNode: focusNode,
              style: textStyle,
              cursorColor: cursorColor,
            ))));
    await tester.tap(find.byType(EditableText));
    await tester.showKeyboard(find.byType(EditableText));
    controller.text = 'test';
    await tester.idle();
    final EditableText editableText =
        tester.firstWidget(find.byType(EditableText));
    expect(editableText.maxLines, equals(1));
    expect(tester.testTextInput.editingState['text'], equals('test'));
    expect(tester.testTextInput.setClientArgs['inputType'],
        equals('TextInputType.text'));
    expect(tester.testTextInput.setClientArgs['inputAction'],
        equals('TextInputAction.done'));
  });

  testWidgets('multiline keyboard is requested when set explicitly',
      (WidgetTester tester) async {
    await tester.pumpWidget(new Directionality(
        textDirection: TextDirection.ltr,
        child: new FocusScope(
            node: focusScopeNode,
            autofocus: true,
            child: new EditableText(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.multiline,
              style: textStyle,
              cursorColor: cursorColor,
            ))));

    await tester.tap(find.byType(EditableText));
    await tester.showKeyboard(find.byType(EditableText));
    controller.text = 'test';
    await tester.idle();
    expect(tester.testTextInput.editingState['text'], equals('test'));
    expect(tester.testTextInput.setClientArgs['inputType'], equals('TextInputType.multiline'));
    expect(tester.testTextInput.setClientArgs['inputAction'], equals('TextInputAction.newline'));
  });

  testWidgets('Correct keyboard is requested when set explicitly and maxLines > 1',
      (WidgetTester tester) async {
    await tester.pumpWidget(new Directionality(
        textDirection: TextDirection.ltr,
        child: new FocusScope(
            node: focusScopeNode,
            autofocus: true,
            child: new EditableText(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.phone,
              maxLines: 3,
              style: textStyle,
              cursorColor: cursorColor,
            ))));

    await tester.tap(find.byType(EditableText));
    await tester.showKeyboard(find.byType(EditableText));
    controller.text = 'test';
    await tester.idle();
    expect(tester.testTextInput.editingState['text'], equals('test'));
    expect(tester.testTextInput.setClientArgs['inputType'], equals('TextInputType.phone'));
    expect(tester.testTextInput.setClientArgs['inputAction'], equals('TextInputAction.done'));
  });

  testWidgets('multiline keyboard is requested when set implicitly',
      (WidgetTester tester) async {
    await tester.pumpWidget(new Directionality(
        textDirection: TextDirection.ltr,
        child: new FocusScope(
            node: focusScopeNode,
            autofocus: true,
            child: new EditableText(
              controller: controller,
              focusNode: focusNode,
              maxLines: 3, // Sets multiline keyboard implicitly.
              style: textStyle,
              cursorColor: cursorColor,
            ))));

    await tester.tap(find.byType(EditableText));
    await tester.showKeyboard(find.byType(EditableText));
    controller.text = 'test';
    await tester.idle();
    expect(tester.testTextInput.editingState['text'], equals('test'));
    expect(tester.testTextInput.setClientArgs['inputType'], equals('TextInputType.multiline'));
    expect(tester.testTextInput.setClientArgs['inputAction'], equals('TextInputAction.newline'));
  });

  testWidgets('single line inputs have correct default keyboard',
      (WidgetTester tester) async {
    await tester.pumpWidget(new Directionality(
        textDirection: TextDirection.ltr,
        child: new FocusScope(
            node: focusScopeNode,
            autofocus: true,
            child: new EditableText(
              controller: controller,
              focusNode: focusNode,
              maxLines: 1, // Sets text keyboard implicitly.
              style: textStyle,
              cursorColor: cursorColor,
            ))));

    await tester.tap(find.byType(EditableText));
    await tester.showKeyboard(find.byType(EditableText));
    controller.text = 'test';
    await tester.idle();
    expect(tester.testTextInput.editingState['text'], equals('test'));
    expect(tester.testTextInput.setClientArgs['inputType'], equals('TextInputType.text'));
    expect(tester.testTextInput.setClientArgs['inputAction'], equals('TextInputAction.done'));
  });

  testWidgets('Changing controller updates EditableText', (WidgetTester tester) async {
    final GlobalKey<EditableTextState> editableTextKey = new GlobalKey<EditableTextState>();
    final TextEditingController controller1 = new TextEditingController(text: 'Wibble');
    final TextEditingController controller2 = new TextEditingController(text: 'Wobble');
    TextEditingController currentController = controller1;
    StateSetter setState;

    Widget builder() {
      return new StatefulBuilder(
        builder: (BuildContext context, StateSetter setter) {
          setState = setter;
          return new Directionality(
            textDirection: TextDirection.ltr,
            child: new Center(
              child: new Material(
                child: new EditableText(
                  key: editableTextKey,
                  controller: currentController,
                  focusNode: new FocusNode(),
                  style: new Typography(platform: TargetPlatform.android).black.subhead,
                  cursorColor: Colors.blue,
                  selectionControls: materialTextSelectionControls,
                  keyboardType: TextInputType.text,
                  onChanged: (String value) {},
                ),
              ),
            ),
          );
        },
      );
    }
    await tester.pumpWidget(builder());
    await tester.showKeyboard(find.byType(EditableText));

    // Verify TextInput.setEditingState is fired with updated text when controller is replaced.
    final List<MethodCall> log = <MethodCall>[];
    SystemChannels.textInput.setMockMethodCallHandler((MethodCall methodCall) {
      log.add(methodCall);
    });
    setState(() {
      currentController = controller2;
    });
    await tester.pump();

    final MethodCall setStateCall = log.firstWhere((MethodCall methodCall) {
      return methodCall.method == 'TextInput.setEditingState';
    });
    final Map<String, dynamic> arguments = setStateCall.arguments;
    expect(arguments['text'], equals('Wobble'));
  });
}
