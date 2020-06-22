// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';

import '../rendering/mock_canvas.dart';
import '../widgets/semantics_tester.dart';

void main() {
  testWidgets('ContainedButton defaults', (WidgetTester tester) async {
    final Finder rawButtonMaterial = find.descendant(
      of: find.byType(ContainedButton),
      matching: find.byType(Material),
    );

    const ColorScheme colorScheme = ColorScheme.light();

    // Enabled ContainedButton
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.from(colorScheme: colorScheme),
        home: Center(
          child: ContainedButton(
            onPressed: () { },
            child: const Text('button'),
          ),
        ),
      ),
    );

    Material material = tester.widget<Material>(rawButtonMaterial);
    expect(material.animationDuration, const Duration(milliseconds: 200));
    expect(material.borderOnForeground, true);
    expect(material.borderRadius, null);
    expect(material.clipBehavior, Clip.none);
    expect(material.color, colorScheme.primary);
    expect(material.elevation, 2);
    expect(material.shadowColor, const Color(0xff000000));
    expect(material.shape, RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)));
    expect(material.textStyle.color, colorScheme.onPrimary);
    expect(material.textStyle.fontFamily, 'Roboto');
    expect(material.textStyle.fontSize, 14);
    expect(material.textStyle.fontWeight, FontWeight.w500);
    expect(material.type, MaterialType.button);

    final Offset center = tester.getCenter(find.byType(ContainedButton));
    await tester.startGesture(center);
    await tester.pumpAndSettle();

    // Only elevation changes when enabled and pressed.
    material = tester.widget<Material>(rawButtonMaterial);
    expect(material.animationDuration, const Duration(milliseconds: 200));
    expect(material.borderOnForeground, true);
    expect(material.borderRadius, null);
    expect(material.clipBehavior, Clip.none);
    expect(material.color, colorScheme.primary);
    expect(material.elevation, 8);
    expect(material.shadowColor, const Color(0xff000000));
    expect(material.shape, RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)));
    expect(material.textStyle.color, colorScheme.onPrimary);
    expect(material.textStyle.fontFamily, 'Roboto');
    expect(material.textStyle.fontSize, 14);
    expect(material.textStyle.fontWeight, FontWeight.w500);
    expect(material.type, MaterialType.button);

    // Disabled ContainedButton
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.from(colorScheme: colorScheme),
        home: const Center(
          child: ContainedButton(
            onPressed: null,
            child: Text('button'),
          ),
        ),
      ),
    );

    material = tester.widget<Material>(rawButtonMaterial);
    expect(material.animationDuration, const Duration(milliseconds: 200));
    expect(material.borderOnForeground, true);
    expect(material.borderRadius, null);
    expect(material.clipBehavior, Clip.none);
    expect(material.color, colorScheme.onSurface.withOpacity(0.12));
    expect(material.elevation, 0.0);
    expect(material.shadowColor, const Color(0xff000000));
    expect(material.shape, RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)));
    expect(material.textStyle.color, colorScheme.onSurface.withOpacity(0.38));
    expect(material.textStyle.fontFamily, 'Roboto');
    expect(material.textStyle.fontSize, 14);
    expect(material.textStyle.fontWeight, FontWeight.w500);
    expect(material.type, MaterialType.button);
  });

  testWidgets('Default ContainedButton meets a11y contrast guidelines', (WidgetTester tester) async {
    final FocusNode focusNode = FocusNode();

    Widget buildWidget(ColorScheme colorScheme) {
      return MaterialApp(
        theme: ThemeData.from(colorScheme: colorScheme),
        home: Scaffold(
          body: Center(
            child: ContainedButton(
              child: const Text('ContainedButton'),
              onPressed: () { },
              focusNode: focusNode,
            ),
          ),
        ),
      );
    }

    Future<void> checkA11yGuidelines() async {
      // Default, not disabled.
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      // Focused.
      focusNode.requestFocus();
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      // Hovered.
      final Offset center = tester.getCenter(find.byType(ContainedButton));
      final TestGesture gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer();
      addTearDown(gesture.removePointer);
      await gesture.moveTo(center);
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      // Highlighted (pressed).
      await gesture.down(center);
      await tester.pump(); // Start the splash and highlight animations.
      await tester.pump(const Duration(milliseconds: 800)); // Wait for splash and highlight to be well under way.
      /*
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      */
    }

    await tester.pumpWidget(buildWidget(const ColorScheme.light()));
    await checkA11yGuidelines();
    /*
    await tester.pumpWidget(buildWidget(const ColorScheme.dark()));
    await checkA11yGuidelines();
    */
  },
    skip: isBrowser, // https://github.com/flutter/flutter/issues/44115
    semanticsEnabled: true,
  );


  testWidgets('ContainedButton uses stateful color for text color in different states', (WidgetTester tester) async {
    final FocusNode focusNode = FocusNode();

    const Color pressedColor = Color(0x00000001);
    const Color hoverColor = Color(0x00000002);
    const Color focusedColor = Color(0x00000003);
    const Color defaultColor = Color(0x00000004);

    Color getTextColor(Set<MaterialState> states) {
      if (states.contains(MaterialState.pressed)) {
        return pressedColor;
      }
      if (states.contains(MaterialState.hovered)) {
        return hoverColor;
      }
      if (states.contains(MaterialState.focused)) {
        return focusedColor;
      }
      return defaultColor;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ContainedButtonTheme(
              data: ContainedButtonThemeData(
                style: ButtonStyle(
                  foregroundColor: MaterialStateProperty.resolveWith<Color>(getTextColor),
                ),
              ),
              child: Builder(
                builder: (BuildContext context) {
                  return ContainedButton(
                    child: const Text('ContainedButton'),
                    onPressed: () {},
                    focusNode: focusNode,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Color textColor() {
      return tester.renderObject<RenderParagraph>(find.text('ContainedButton')).text.style.color;
    }

    // Default, not disabled.
    expect(textColor(), equals(defaultColor));

    // Focused.
    focusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(textColor(), focusedColor);

    // Hovered.
    final Offset center = tester.getCenter(find.byType(ContainedButton));
    final TestGesture gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await gesture.addPointer();
    addTearDown(gesture.removePointer);
    await gesture.moveTo(center);
    await tester.pumpAndSettle();
    expect(textColor(), hoverColor);

    // Highlighted (pressed).
    await gesture.down(center);
    await tester.pump(); // Start the splash and highlight animations.
    await tester.pump(const Duration(milliseconds: 800)); // Wait for splash and highlight to be well under way.
    expect(textColor(), pressedColor);
  });


  testWidgets('ContainedButton uses stateful color for icon color in different states', (WidgetTester tester) async {
    final FocusNode focusNode = FocusNode();
    final Key buttonKey = UniqueKey();

    const Color pressedColor = Color(0x00000001);
    const Color hoverColor = Color(0x00000002);
    const Color focusedColor = Color(0x00000003);
    const Color defaultColor = Color(0x00000004);

    Color getTextColor(Set<MaterialState> states) {
      if (states.contains(MaterialState.pressed)) {
        return pressedColor;
      }
      if (states.contains(MaterialState.hovered)) {
        return hoverColor;
      }
      if (states.contains(MaterialState.focused)) {
        return focusedColor;
      }
      return defaultColor;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ContainedButtonTheme(
              data: ContainedButtonThemeData(
                style: ButtonStyle(
                  foregroundColor: MaterialStateProperty.resolveWith<Color>(getTextColor),
                ),
              ),
              child: Builder(
                builder: (BuildContext context) {
                  return ContainedButton.icon(
                    key: buttonKey,
                    icon: const Icon(Icons.add),
                    label: const Text('ContainedButton'),
                    onPressed: () {},
                    focusNode: focusNode,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Color iconColor() => _iconStyle(tester, Icons.add).color;
    // Default, not disabled.
    expect(iconColor(), equals(defaultColor));

    // Focused.
    focusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(iconColor(), focusedColor);

    // Hovered.
    final Offset center = tester.getCenter(find.byKey(buttonKey));
    final TestGesture gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await gesture.addPointer();
    addTearDown(gesture.removePointer);
    await gesture.moveTo(center);
    await tester.pumpAndSettle();
    expect(iconColor(), hoverColor);

    // Highlighted (pressed).
    await gesture.down(center);
    await tester.pump(); // Start the splash and highlight animations.
    await tester.pump(const Duration(milliseconds: 800)); // Wait for splash and highlight to be well under way.
    expect(iconColor(), pressedColor);
  });

  testWidgets('ContainedButton onPressed and onLongPress callbacks are correctly called when non-null', (WidgetTester tester) async {
    bool wasPressed;
    Finder containedButton;

    Widget buildFrame({ VoidCallback onPressed, VoidCallback onLongPress }) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: ContainedButton(
          child: const Text('button'),
          onPressed: onPressed,
          onLongPress: onLongPress,
        ),
      );
    }

    // onPressed not null, onLongPress null.
    wasPressed = false;
    await tester.pumpWidget(
      buildFrame(onPressed: () { wasPressed = true; }, onLongPress: null),
    );
    containedButton = find.byType(ContainedButton);
    expect(tester.widget<ContainedButton>(containedButton).enabled, true);
    await tester.tap(containedButton);
    expect(wasPressed, true);

    // onPressed null, onLongPress not null.
    wasPressed = false;
    await tester.pumpWidget(
      buildFrame(onPressed: null, onLongPress: () { wasPressed = true; }),
    );
    containedButton = find.byType(ContainedButton);
    expect(tester.widget<ContainedButton>(containedButton).enabled, true);
    await tester.longPress(containedButton);
    expect(wasPressed, true);

    // onPressed null, onLongPress null.
    await tester.pumpWidget(
      buildFrame(onPressed: null, onLongPress: null),
    );
    containedButton = find.byType(ContainedButton);
    expect(tester.widget<ContainedButton>(containedButton).enabled, false);
  });

  testWidgets('ContainedButton onPressed and onLongPress callbacks are distinctly recognized', (WidgetTester tester) async {
    bool didPressButton = false;
    bool didLongPressButton = false;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ContainedButton(
          onPressed: () {
            didPressButton = true;
          },
          onLongPress: () {
            didLongPressButton = true;
          },
          child: const Text('button'),
        ),
      ),
    );

    final Finder containedButton = find.byType(ContainedButton);
    expect(tester.widget<ContainedButton>(containedButton).enabled, true);

    expect(didPressButton, isFalse);
    await tester.tap(containedButton);
    expect(didPressButton, isTrue);

    expect(didLongPressButton, isFalse);
    await tester.longPress(containedButton);
    expect(didLongPressButton, isTrue);
  });

  testWidgets('Does ContainedButton work with hover', (WidgetTester tester) async {
    const Color hoverColor = Color(0xff001122);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ContainedButton(
          style: ButtonStyle(
            overlayColor: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
              return states.contains(MaterialState.hovered) ? hoverColor : null;
            }),
          ),
          onPressed: () { },
          child: const Text('button'),
        ),
      ),
    );

    final TestGesture gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    await gesture.moveTo(tester.getCenter(find.byType(ContainedButton)));
    await tester.pumpAndSettle();

    final RenderObject inkFeatures = tester.allRenderObjects.firstWhere((RenderObject object) => object.runtimeType.toString() == '_RenderInkFeatures');
    expect(inkFeatures, paints..rect(color: hoverColor));

    await gesture.removePointer();
  });

  testWidgets('Does ContainedButton work with focus', (WidgetTester tester) async {
    const Color focusColor = Color(0xff001122);

    final FocusNode focusNode = FocusNode(debugLabel: 'ContainedButton Node');
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ContainedButton(
          style: ButtonStyle(
            overlayColor: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
              return states.contains(MaterialState.focused) ? focusColor : null;
            }),
          ),
          focusNode: focusNode,
          onPressed: () { },
          child: const Text('button'),
        ),
      ),
    );

    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    focusNode.requestFocus();
    await tester.pumpAndSettle();

    final RenderObject inkFeatures = tester.allRenderObjects.firstWhere((RenderObject object) => object.runtimeType.toString() == '_RenderInkFeatures');
    expect(inkFeatures, paints..rect(color: focusColor));
  });

  testWidgets('Does ContainedButton contribute semantics', (WidgetTester tester) async {
    final SemanticsTester semantics = SemanticsTester(tester);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          child: Center(
            child: ContainedButton(
              style: ButtonStyle(
                // Specifying minimumSize to mimic the original minimumSize for
                // RaisedButton so that the semantics tree's rect and transform
                // match the original version of this test.
                minimumSize: MaterialStateProperty.all<Size>(const Size(88, 36)),
              ),
              onPressed: () { },
              child: const Text('ABC'),
            ),
          ),
        ),
      ),
    );

    expect(semantics, hasSemantics(
      TestSemantics.root(
        children: <TestSemantics>[
          TestSemantics.rootChild(
            actions: <SemanticsAction>[
              SemanticsAction.tap,
            ],
            label: 'ABC',
            rect: const Rect.fromLTRB(0.0, 0.0, 88.0, 48.0),
            transform: Matrix4.translationValues(356.0, 276.0, 0.0),
            flags: <SemanticsFlag>[
              SemanticsFlag.hasEnabledState,
              SemanticsFlag.isButton,
              SemanticsFlag.isEnabled,
              SemanticsFlag.isFocusable,
            ],
          ),
        ],
      ),
      ignoreId: true,
    ));

    semantics.dispose();
  });

  testWidgets('ContainedButton size is configurable by ThemeData.materialTapTargetSize', (WidgetTester tester) async {
    final Key key1 = UniqueKey();
    final ButtonStyle style = ButtonStyle(
      // Specifying minimumSize to mimic the original minimumSize for
      // RaisedButton so that the corresponding button size matches
      // the original version of this test.
      minimumSize: MaterialStateProperty.all<Size>(const Size(88, 36)),
    );

    await tester.pumpWidget(
      Theme(
        data: ThemeData(materialTapTargetSize: MaterialTapTargetSize.padded),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Material(
            child: Center(
              child: ContainedButton(
                key: key1,
                style: style,
                child: const SizedBox(width: 50.0, height: 8.0),
                onPressed: () { },
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(key1)), const Size(88.0, 48.0));

    final Key key2 = UniqueKey();
    await tester.pumpWidget(
      Theme(
        data: ThemeData(materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Material(
            child: Center(
              child: ContainedButton(
                style: style,
                key: key2,
                child: const SizedBox(width: 50.0, height: 8.0),
                onPressed: () { },
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(key2)), const Size(88.0, 36.0));
  });

  testWidgets('ContainedButton has no clip by default', (WidgetTester tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          child: ContainedButton(
            onPressed: () { /* to make sure the button is enabled */ },
            child: const Text('button'),
          ),
        ),
      ),
    );

    expect(
      tester.renderObject(find.byType(ContainedButton)),
      paintsExactlyCountTimes(#clipPath, 0),
    );
  });

  testWidgets('ContainedButton responds to density changes.', (WidgetTester tester) async {
    const Key key = Key('test');
    const Key childKey = Key('test child');

    Future<void> buildTest(VisualDensity visualDensity, {bool useText = false}) async {
      return await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Center(
              child: ContainedButton(
                style: ButtonStyle(
                  visualDensity: visualDensity,
                  // Specifying minimumSize to mimic the original minimumSize for
                  // RaisedButton so that the corresponding button size matches
                  // the original version of this test.
                  minimumSize: MaterialStateProperty.all<Size>(const Size(88, 36)),
                ),
                key: key,
                onPressed: () {},
                child: useText
                  ? const Text('Text', key: childKey)
                  : Container(key: childKey, width: 100, height: 100, color: const Color(0xffff0000)),
              ),
            ),
          ),
        ),
      );
    }

    await buildTest(const VisualDensity());
    final RenderBox box = tester.renderObject(find.byKey(key));
    Rect childRect = tester.getRect(find.byKey(childKey));
    await tester.pumpAndSettle();
    expect(box.size, equals(const Size(132, 100)));
    expect(childRect, equals(const Rect.fromLTRB(350, 250, 450, 350)));

    await buildTest(const VisualDensity(horizontal: 3.0, vertical: 3.0));
    await tester.pumpAndSettle();
    childRect = tester.getRect(find.byKey(childKey));
    expect(box.size, equals(const Size(156, 124)));
    expect(childRect, equals(const Rect.fromLTRB(350, 250, 450, 350)));

    await buildTest(const VisualDensity(horizontal: -3.0, vertical: -3.0));
    await tester.pumpAndSettle();
    childRect = tester.getRect(find.byKey(childKey));
    expect(box.size, equals(const Size(108, 100)));
    expect(childRect, equals(const Rect.fromLTRB(350, 250, 450, 350)));

    await buildTest(const VisualDensity(), useText: true);
    await tester.pumpAndSettle();
    childRect = tester.getRect(find.byKey(childKey));
    expect(box.size, equals(const Size(88, 48)));
    expect(childRect, equals(const Rect.fromLTRB(372.0, 293.0, 428.0, 307.0)));

    await buildTest(const VisualDensity(horizontal: 3.0, vertical: 3.0), useText: true);
    await tester.pumpAndSettle();
    childRect = tester.getRect(find.byKey(childKey));
    expect(box.size, equals(const Size(112, 60)));
    expect(childRect, equals(const Rect.fromLTRB(372.0, 293.0, 428.0, 307.0)));

    await buildTest(const VisualDensity(horizontal: -3.0, vertical: -3.0), useText: true);
    await tester.pumpAndSettle();
    childRect = tester.getRect(find.byKey(childKey));
    expect(box.size, equals(const Size(76, 36)));
    expect(childRect, equals(const Rect.fromLTRB(372.0, 293.0, 428.0, 307.0)));
  });

  testWidgets('ContainedButton.icon responds to applied padding', (WidgetTester tester) async {
    const Key buttonKey = Key('test');
    const Key labelKey = Key('label');
    await tester.pumpWidget(
      // When textDirection is set to TextDirection.ltr, the label appears on the
      // right side of the icon. This is important in determining whether the
      // horizontal padding is applied correctly later on
      Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          child: Center(
            child: ContainedButton.icon(
              key: buttonKey,
              style: ButtonStyle(
                padding: MaterialStateProperty.all<EdgeInsets>(const EdgeInsets.fromLTRB(16, 5, 10, 12)),
              ),
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text(
                'Hello',
                key: labelKey,
              ),
            ),
          ),
        ),
      ),
    );

    final Rect paddingRect = tester.getRect(find.byType(Padding));
    final Rect labelRect = tester.getRect(find.byKey(labelKey));
    final Rect iconRect = tester.getRect(find.byType(Icon));

    // The right padding should be applied on the right of the label, whereas the
    // left padding should be applied on the left side of the icon.
    expect(paddingRect.right, labelRect.right + 10);
    expect(paddingRect.left, iconRect.left - 16);
    // Use the taller widget to check the top and bottom padding.
    final Rect tallerWidget = iconRect.height > labelRect.height ? iconRect : labelRect;
    expect(paddingRect.top, tallerWidget.top - 5);
    expect(paddingRect.bottom, tallerWidget.bottom + 12);
  });

}

TextStyle _iconStyle(WidgetTester tester, IconData icon) {
  final RichText iconRichText = tester.widget<RichText>(
    find.descendant(of: find.byIcon(icon), matching: find.byType(RichText)),
  );
  return iconRichText.text.style;
}
