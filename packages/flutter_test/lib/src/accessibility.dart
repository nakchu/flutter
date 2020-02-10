// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' as flutter_material;
import 'package:flutter/rendering.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'finders.dart';
import 'widget_tester.dart';

/// The result of evaluating a semantics node by a [AccessibilityGuideline].
class Evaluation {
  /// Create a passing evaluation.
  const Evaluation.pass()
    : passed = true,
      reason = null;

  /// Create a failing evaluation, with an optional [reason] explaining the
  /// result.
  const Evaluation.fail([this.reason]) : passed = false;

  // private constructor for adding cases together.
  const Evaluation._(this.passed, this.reason);

  /// Whether the given tree or node passed the policy evaluation.
  final bool passed;

  /// If [passed] is false, contains the reason for failure.
  final String reason;

  /// Combines two evaluation results.
  ///
  /// The [reason] will be concatenated with a newline, and [passed] will be
  /// combined with an `&&` operator.
  Evaluation operator +(Evaluation other) {
    if (other == null)
      return this;
    final StringBuffer buffer = StringBuffer();
    if (reason != null) {
      buffer.write(reason);
      buffer.write(' ');
    }
    if (other.reason != null)
      buffer.write(other.reason);
    return Evaluation._(passed && other.passed, buffer.isEmpty ? null : buffer.toString());
  }
}

/// An accessibility guideline describes a recommendation an application should
/// meet to be considered accessible.
abstract class AccessibilityGuideline {
  /// A const constructor allows subclasses to be const.
  const AccessibilityGuideline();

  /// Evaluate whether the current state of the `tester` conforms to the rule.
  FutureOr<Evaluation> evaluate(WidgetTester tester);

  /// A description of the policy restrictions and criteria.
  String get description;
}

/// A guideline which enforces that all tappable semantics nodes have a minimum
/// size.
///
/// Each platform defines its own guidelines for minimum tap areas.
@visibleForTesting
class MinimumTapTargetGuideline extends AccessibilityGuideline {
  const MinimumTapTargetGuideline._(this.size, this.link);

  /// The minimum allowed size of a tappable node.
  final Size size;

  /// A link describing the tap target guidelines for a platform.
  final String link;

  @override
  FutureOr<Evaluation> evaluate(WidgetTester tester) {
    final SemanticsNode root = tester.binding.pipelineOwner.semanticsOwner.rootSemanticsNode;
    Evaluation traverse(SemanticsNode node) {
      Evaluation result = const Evaluation.pass();
      node.visitChildren((SemanticsNode child) {
        result += traverse(child);
        return true;
      });
      if (node.isMergedIntoParent)
        return result;
      final SemanticsData data = node.getSemanticsData();
      // Skip node if it has no actions, or is marked as hidden.
      if ((!data.hasAction(ui.SemanticsAction.longPress)
        && !data.hasAction(ui.SemanticsAction.tap))
        || data.hasFlag(ui.SemanticsFlag.isHidden))
        return result;
      Rect paintBounds = node.rect;
      SemanticsNode current = node;
      while (current != null) {
        if (current.transform != null)
          paintBounds = MatrixUtils.transformRect(current.transform, paintBounds);
        current = current.parent;
      }
      // skip node if it is touching the edge of the screen, since it might
      // be partially scrolled offscreen.
      const double delta = 0.001;
      if (paintBounds.left <= delta
        || paintBounds.top <= delta
        || (paintBounds.bottom - tester.binding.window.physicalSize.height).abs() <= delta
        || (paintBounds.right - tester.binding.window.physicalSize.width).abs() <= delta)
        return result;
      // shrink by device pixel ratio.
      final Size candidateSize = paintBounds.size / tester.binding.window.devicePixelRatio;
      if (candidateSize.width < size.width - delta || candidateSize.height < size.height - delta) {
        result += Evaluation.fail(
          '$node: expected tap target size of at least $size, but found $candidateSize\n'
          'See also: $link');
      }
      return result;
    }
    return traverse(root);
  }

  @override
  String get description => 'Tappable objects should be at least $size';
}

/// A guideline which enforces that all nodes with a tap or long press action
/// also have a label.
@visibleForTesting
class LabeledTapTargetGuideline extends AccessibilityGuideline {
  const LabeledTapTargetGuideline._();

  @override
  String get description => 'Tappable widgets should have a semantic label';

  @override
  FutureOr<Evaluation> evaluate(WidgetTester tester) {
    final SemanticsNode root = tester.binding.pipelineOwner.semanticsOwner.rootSemanticsNode;
    Evaluation traverse(SemanticsNode node) {
      Evaluation result = const Evaluation.pass();
      node.visitChildren((SemanticsNode child) {
        result += traverse(child);
        return true;
      });
      if (node.isMergedIntoParent || node.isInvisible || node.hasFlag(ui.SemanticsFlag.isHidden))
        return result;
      final SemanticsData data = node.getSemanticsData();
      // Skip node if it has no actions, or is marked as hidden.
      if (!data.hasAction(ui.SemanticsAction.longPress) && !data.hasAction(ui.SemanticsAction.tap))
        return result;
      if (data.label == null || data.label.isEmpty) {
        result += Evaluation.fail(
          '$node: expected tappable node to have semantic label, but none was found\n',
        );
      }
      return result;
    }
    return traverse(root);
  }
}

/// A guideline which verifies that all nodes that contribute semantics via text
/// meet minimum contrast levels.
///
/// The guidelines are defined by the Web Content Accessibility Guidelines,
/// http://www.w3.org/TR/UNDERSTANDING-WCAG20/visual-audio-contrast-contrast.html.
@visibleForTesting
class MinimumTextContrastGuideline extends AccessibilityGuideline {
  const MinimumTextContrastGuideline._();

  /// The minimum text size considered large for contrast checking.
  ///
  /// Defined by http://www.w3.org/TR/UNDERSTANDING-WCAG20/visual-audio-contrast-contrast.html
  static const int kLargeTextMinimumSize = 18;

  /// The minimum text size for bold text to be considered large for contrast
  /// checking.
  ///
  /// Defined by http://www.w3.org/TR/UNDERSTANDING-WCAG20/visual-audio-contrast-contrast.html
  static const int kBoldTextMinimumSize = 14;

  /// The minimum contrast ratio for normal text.
  ///
  /// Defined by http://www.w3.org/TR/UNDERSTANDING-WCAG20/visual-audio-contrast-contrast.html
  static const double kMinimumRatioNormalText = 4.5;

  /// The minimum contrast ratio for large text.
  ///
  /// Defined by http://www.w3.org/TR/UNDERSTANDING-WCAG20/visual-audio-contrast-contrast.html
  static const double kMinimumRatioLargeText = 3.0;

  @override
  Future<Evaluation> evaluate(WidgetTester tester) async {
    final RenderView renderView = tester.binding.renderView;
    final OffsetLayer layer = renderView.debugLayer as OffsetLayer;
    ui.Image image;
    final ByteData byteData = await tester.binding.runAsync<ByteData>(() async {
      // Needs to be the same pixel ratio otherwise our dimensions won't match the
      // last transform layer.
      image = await layer.toImage(renderView.paintBounds, pixelRatio: 1 / tester.binding.window.devicePixelRatio);
      return image.toByteData();
    });

    List<RenderObject> childrenByPredicate(RenderObject renderObject, bool Function(RenderObject) predicate) {
      final List<RenderObject> result = <RenderObject>[];

      void collectChildrenByPredicate(RenderObject renderObject) {
        if (predicate(renderObject)) {
          result.add(renderObject);
        }

        renderObject.visitChildrenForSemantics(collectChildrenByPredicate);
      }

      collectChildrenByPredicate(renderObject);

      return result;
    }

    // Find render objects for texts.

    final Set<RenderObject> textRenderObjects = childrenByPredicate(
      tester.allRenderObjects.first,
      (RenderObject renderObject) => renderObject is RenderParagraph || renderObject is RenderEditable,
    ).toSet();

    // Find text elements that contribute to semantics.

    final Iterable<Element> textElements = find
        .byWidgetPredicate((Widget widget) => widget is Text || widget is EditableText)
        .evaluate();

    final List<Element> textElementsContributingToSemantics = <Element>[];

    bool hasTextRenderObjectAsChild(RenderObject renderObject) {
      final List<RenderObject> textRenderObjectChildren = childrenByPredicate(
        renderObject,
        (RenderObject childRenderObject) => textRenderObjects.contains(childRenderObject),
      );
      return textRenderObjectChildren.isNotEmpty;
    }

    for (final Element element in textElements) {
      if (hasTextRenderObjectAsChild(element.renderObject)) {
        textElementsContributingToSemantics.add(element);
      }
    }

    Future<Evaluation> evaluateElement(Element element) async {
      // We need to look up the inherited text properties to determine the
      // contrast ratio based on text size/weight.

      double fontSize;
      bool isBold;

      final RenderBox renderObject = element.renderObject as RenderBox;

      final Rect originalPaintBounds = renderObject.paintBounds;

      final Rect inflatedPaintBounds = originalPaintBounds.inflate(4.0);

      final Rect paintBounds = Rect.fromPoints(
        renderObject.localToGlobal(inflatedPaintBounds.topLeft),
        renderObject.localToGlobal(inflatedPaintBounds.bottomRight),
      );

      final Widget widget = element.widget;
      final DefaultTextStyle defaultTextStyle = DefaultTextStyle.of(element);
      if (widget is Text) {
        TextStyle effectiveTextStyle = widget.style;
        if (widget.style == null || widget.style.inherit) {
          effectiveTextStyle = defaultTextStyle.style.merge(widget.style);
        }
        fontSize = effectiveTextStyle.fontSize;
        isBold = effectiveTextStyle.fontWeight == FontWeight.bold;
      } else if (widget is EditableText) {
        isBold = widget.style.fontWeight == FontWeight.bold;
        fontSize = widget.style.fontSize;
      } else {
        assert(false);
      }

      final List<int> subset = _colorsWithinRect(byteData, paintBounds, image.width, image.height);
      final _ContrastReport report = _ContrastReport(subset);

      // If rectangle is empty, pass the test.
      if (report.isEmptyRect) {
        return const Evaluation.pass();
      }
      final double contrastRatio = report.contrastRatio();
      const double delta = -0.01;
      double targetContrastRatio;
      if ((isBold && fontSize > kBoldTextMinimumSize) || (fontSize ?? 12.0) > kLargeTextMinimumSize) {
        targetContrastRatio = kMinimumRatioLargeText;
      } else {
        targetContrastRatio = kMinimumRatioNormalText;
      }
      if (contrastRatio - targetContrastRatio >= delta) {
        return const Evaluation.pass();
      }
      return Evaluation.fail(
        '${element.renderObject.debugSemantics}:\nExpected contrast ratio of at least '
        '$targetContrastRatio but found ${contrastRatio.toStringAsFixed(2)} for a font size of $fontSize. '
        'The computed light color was: ${report.lightColor}, '
        'The computed dark color was: ${report.darkColor}\n'
        'See also: https://www.w3.org/TR/UNDERSTANDING-WCAG20/visual-audio-contrast-contrast.html'
      );
    }

    Evaluation result = const Evaluation.pass();

    for (final Element element in textElementsContributingToSemantics) {
      result = result + await evaluateElement(element);
    }

    return result;
  }

  @override
  String get description => 'Text contrast should follow WCAG guidelines';
}

/// A guideline which verifies that all elements specified by [finder]
/// meet minimum contrast levels.
class CustomMinimumContrastGuideline extends AccessibilityGuideline {
  /// Creates a custom guideline which verifies that all elements specified
  /// by [finder] meet minimum contrast levels.
  ///
  /// An optional description string can be given using the [description] parameter.
  const CustomMinimumContrastGuideline({
    @required this.finder,
    this.minimumRatio = 4.5,
    this.tolerance = 0.01,
    String description = 'Contrast should follow custom guidelines',
  }) : _description = description;

  /// The minimum contrast ratio allowed.
  ///
  /// Defaults to 4.5, the minimum contrast
  /// ratio for normal text, defined by WCAG.
  /// See http://www.w3.org/TR/UNDERSTANDING-WCAG20/visual-audio-contrast-contrast.html.
  final double minimumRatio;

  /// Tolerance for minimum contrast ratio.
  ///
  /// Any contrast ratio greater than [minimumRatio] or within a distance of [tolerance]
  /// from [minimumRatio] passes the test.
  /// Defaults to 0.01.
  final double tolerance;

  /// The [Finder] used to find a subset of elements.
  ///
  /// [finder] determines which subset of elements will be tested for
  /// contrast ratio.
  final Finder finder;

  final String _description;

  @override
  String get description => _description;

  @override
  Future<Evaluation> evaluate(WidgetTester tester) async {
    // Compute elements to be evaluated.

    final List<Element> elements = finder.evaluate().toList();

    // Obtain rendered image.

    final RenderView renderView = tester.binding.renderView;
    final OffsetLayer layer = renderView.debugLayer as OffsetLayer;
    ui.Image image;
    final ByteData byteData = await tester.binding.runAsync<ByteData>(() async {
      // Needs to be the same pixel ratio otherwise our dimensions won't match the
      // last transform layer.
      image = await layer.toImage(renderView.paintBounds, pixelRatio: 1 / tester.binding.window.devicePixelRatio);
      return image.toByteData();
    });

    // How to evaluate a single element.

    Evaluation evaluateElement(Element element) {
      final RenderBox renderObject = element.renderObject as RenderBox;

      final Rect originalPaintBounds = renderObject.paintBounds;

      final Rect inflatedPaintBounds = originalPaintBounds.inflate(4.0);

      final Rect paintBounds = Rect.fromPoints(
        renderObject.localToGlobal(inflatedPaintBounds.topLeft),
        renderObject.localToGlobal(inflatedPaintBounds.bottomRight),
      );

      final List<int> subset = _colorsWithinRect(byteData, paintBounds, image.width, image.height);

      if (subset.isEmpty) {
        return const Evaluation.pass();
      }

      final _ContrastReport report = _ContrastReport(subset);
      final double contrastRatio = report.contrastRatio();

      if (report.isEmptyRect || contrastRatio >= minimumRatio - tolerance) {
        return const Evaluation.pass();
      } else {
        return Evaluation.fail(
            '$element:\nExpected contrast ratio of at least '
                '$minimumRatio but found ${contrastRatio.toStringAsFixed(2)} \n'
                'The computed light color was: ${report.lightColor}, '
                'The computed dark color was: ${report.darkColor}\n'
                '$description'
        );
      }
    }

    // Collate all evaluations into a final evaluation, then return.

    Evaluation result = const Evaluation.pass();

    for (final Element element in elements) {
      result = result + evaluateElement(element);
    }

    return result;
  }
}

/// A class that reports the contrast ratio of a part of the screen.
///
/// Commonly used in accessibility testing to obtain the contrast ratio of
/// text widgets and other types of widgets.
class _ContrastReport {
  /// Generates a contrast report given a list of colors.
  ///
  /// Given a list of integers [colors], each representing the color of a pixel
  /// on a part of the screen, generates a contrast ratio report.
  /// Each colors is given in in ARGB format, as is the parameter for the
  /// constructor [Color].
  ///
  /// The contrast ratio of the most frequent light color and the most
  /// frequent dark color is calculated. Colors are divided into light and
  /// dark colors based on their lightness as an [HSLColor].
  factory _ContrastReport(List<int> colors) {
    final Map<int, int> colorHistogram = <int, int>{};
    for (final int color in colors) {
      colorHistogram[color] = (colorHistogram[color] ?? 0) + 1;
    }
    if (colorHistogram.length == 1) {
      final Color hslColor = Color(colorHistogram.keys.first);
      return _ContrastReport._(hslColor, hslColor);
    }
    // to determine the lighter and darker color, partition the colors
    // by lightness and then choose the mode from each group.
    double averageLightness = 0.0;
    for (final int color in colorHistogram.keys) {
      final HSLColor hslColor = HSLColor.fromColor(Color(color));
      averageLightness += hslColor.lightness * colorHistogram[color];
    }
    averageLightness /= colors.length;
    assert(averageLightness != double.nan);
    int lightColor = 0;
    int darkColor = 0;
    int lightCount = 0;
    int darkCount = 0;
    // Find the most frequently occurring light and dark color.
    for (final MapEntry<int, int> entry in colorHistogram.entries) {
      final HSLColor color = HSLColor.fromColor(Color(entry.key));
      final int count = entry.value;
      if (color.lightness <= averageLightness && count > darkCount) {
        darkColor = entry.key;
        darkCount = count;
      } else if (color.lightness > averageLightness && count > lightCount) {
        lightColor = entry.key;
        lightCount = count;
      }
    }
    // Depending on the number of colors present, return the correct contrast
    // report.
    if (lightCount > 0 && darkCount > 0) {
      return _ContrastReport._(Color(lightColor), Color(darkColor));
    } else if (lightCount > 0) {
      return _ContrastReport.singleColor(Color(lightColor));
    } else if (darkCount > 0) {
      return _ContrastReport.singleColor(Color(darkColor));
    } else {
      return const _ContrastReport.emptyRect();
    }
  }

  const _ContrastReport._(this.lightColor, this.darkColor)
      : isSingleColor = false,
        isEmptyRect = false;

  const _ContrastReport.singleColor(Color color)
      : lightColor = color,
        darkColor = color,
        isSingleColor = true,
        isEmptyRect = false;

  const _ContrastReport.emptyRect()
      : lightColor = flutter_material.Colors.transparent,
        darkColor = flutter_material.Colors.transparent,
        isSingleColor = false,
        isEmptyRect = true;

  /// The most frequently occurring light color. Uses [Colors.transparent] if
  /// the rectangle is empty.
  final Color lightColor;

  /// The most frequently occurring dark color. Uses [Colors.transparent] if
  /// the rectangle is empty.
  final Color darkColor;

  /// Whether the rectangle contains only one color.
  final bool isSingleColor;

  /// Whether the rectangle contains 0 pixels.
  final bool isEmptyRect;

  /// Computes the contrast ratio as defined by the WCAG.
  ///
  /// source: https://www.w3.org/TR/UNDERSTANDING-WCAG20/visual-audio-contrast-contrast.html
  double contrastRatio() {
    return (_luminance(lightColor) + 0.05) / (_luminance(darkColor) + 0.05);
  }

  /// Relative luminance calculation.
  ///
  /// Based on https://www.w3.org/TR/2008/REC-WCAG20-20081211/#relativeluminancedef
  static double _luminance(Color color) {
    double r = color.red / 255.0;
    double g = color.green / 255.0;
    double b = color.blue / 255.0;
    if (r <= 0.03928)
      r /= 12.92;
    else
      r = math.pow((r + 0.055)/ 1.055, 2.4).toDouble();
    if (g <= 0.03928)
      g /= 12.92;
    else
      g = math.pow((g + 0.055)/ 1.055, 2.4).toDouble();
    if (b <= 0.03928)
      b /= 12.92;
    else
      b = math.pow((b + 0.055)/ 1.055, 2.4).toDouble();
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }
}

/// Gives the colors of all pixels inside a given rectangle on the screen.
///
/// Given a [ByteData] object [data], which stores the color of each pixel
/// in row-first order, where each pixel is given in 4 bytes in RGBA order,
/// and [paintBounds], the rectangle,
/// and [width] and [height], the dimensions of the [ByteData],
/// returns a list of the colors of all pixels within the rectangle in
/// row-first order.
///
/// In the returned list, each color is represented as a 32-bit integer
/// in ARGB format, similar to the parameter for the [Color] constructor.
List<int> _colorsWithinRect(ByteData data, Rect paintBounds, int width, int height) {
  final Rect truePaintBounds = paintBounds.intersect(
    Rect.fromLTWH(0.0, 0.0, width.toDouble(), height.toDouble()),
  );

  final int leftX   = truePaintBounds.left.floor();
  final int rightX  = truePaintBounds.right.ceil();
  final int topY    = truePaintBounds.top.floor();
  final int bottomY = truePaintBounds.bottom.ceil();

  final List<int> buffer = <int>[];

  int _getPixel(ByteData data, int x, int y) {
    final int offset = (y * width + x) * 4;
    final int r = data.getUint8(offset);
    final int g = data.getUint8(offset + 1);
    final int b = data.getUint8(offset + 2);
    final int a = data.getUint8(offset + 3);
    final int color = (((a & 0xff) << 24) |
    ((r & 0xff) << 16) |
    ((g & 0xff) << 8)  |
    ((b & 0xff) << 0)) & 0xFFFFFFFF;
    return color;
  }

  for (int x = leftX; x < rightX; x ++) {
    for (int y = topY; y < bottomY; y ++) {
      buffer.add(_getPixel(data, x, y));
    }
  }

  return buffer;
}

/// A guideline which requires tappable semantic nodes a minimum size of 48 by 48.
///
/// See also:
///
///  * [Android tap target guidelines](https://support.google.com/accessibility/android/answer/7101858?hl=en).
const AccessibilityGuideline androidTapTargetGuideline = MinimumTapTargetGuideline._(
  Size(48.0, 48.0),
  'https://support.google.com/accessibility/android/answer/7101858?hl=en',
);

/// A guideline which requires tappable semantic nodes a minimum size of 44 by 44.
///
/// See also:
///
///   * [iOS human interface guidelines](https://developer.apple.com/design/human-interface-guidelines/ios/visual-design/adaptivity-and-layout/).
const AccessibilityGuideline iOSTapTargetGuideline = MinimumTapTargetGuideline._(
  Size(44.0, 44.0),
  'https://developer.apple.com/design/human-interface-guidelines/ios/visual-design/adaptivity-and-layout/',
);

/// A guideline which requires text contrast to meet minimum values.
///
/// This guideline traverses the semantics tree looking for nodes with values or
/// labels that corresponds to a Text or Editable text widget. Given the
/// background pixels for the area around this widget, it performs a very naive
/// partitioning of the colors into "light" and "dark" and then chooses the most
/// frequently occurring color in each partition as a representative of the
/// foreground and background colors. The contrast ratio is calculated from
/// these colors according to the [WCAG](https://www.w3.org/TR/UNDERSTANDING-WCAG20/visual-audio-contrast-contrast.html#contrast-ratiodef)
const AccessibilityGuideline textContrastGuideline = MinimumTextContrastGuideline._();

/// A guideline which enforces that all nodes with a tap or long press action
/// also have a label.
const AccessibilityGuideline labeledTapTargetGuideline = LabeledTapTargetGuideline._();
