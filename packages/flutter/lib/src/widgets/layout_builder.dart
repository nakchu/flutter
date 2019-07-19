// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'debug.dart';
import 'framework.dart';

/// The signature of the [LayoutBuilder] builder function.
typedef LayoutWidgetBuilder = Widget Function(BuildContext context, BoxConstraints constraints);

/// The signature of the [SliverLayoutBuilder] builder function.
typedef SliverLayoutWidgetBuilder = Widget Function(BuildContext context, SliverConstraints constraints);

/// An abstract superclass for widgets that defer their building until layout.
///
/// Similar to the [Builder] widget except that the framework calls the [builder]
/// function at layout time and provides the constraints that this widget should
/// adhere to. This is useful when the parent constrains the child's size and layout,
/// and doesn't depend on the child's intrinsic size.
abstract class ConstrainedLayoutBuilder<ConstraintType extends Constraints> extends RenderObjectWidget {
  /// Creates a widget that defers its building until layout.
  ///
  /// The [builder] argument must not be null, and the returned widget should not
  /// be null.
  const ConstrainedLayoutBuilder({
    Key key,
    @required this.builder,
  }) : assert(builder != null),
       super(key: key);

  @override
  _LayoutBuilderElement<ConstraintType> createElement() => _LayoutBuilderElement<ConstraintType>(this);

  /// Called at layout time to construct the widget tree. The builder must not
  /// return null.
  final Widget Function(BuildContext, ConstraintType) builder;

  // updateRenderObject is redundant with the logic in the LayoutBuilderElement below.
}

class _LayoutBuilderElement<ConstraintType extends Constraints> extends RenderObjectElement {
  _LayoutBuilderElement(ConstrainedLayoutBuilder<ConstraintType> widget) : super(widget);

  @override
  ConstrainedLayoutBuilder<ConstraintType> get widget => super.widget;

  @override
  RenderConstrainedLayoutBuilder<ConstraintType, RenderObject> get renderObject => super.renderObject;

  Element _child;

  @override
  void visitChildren(ElementVisitor visitor) {
    if (_child != null)
      visitor(_child);
  }

  @override
  void forgetChild(Element child) {
    assert(child == _child);
    _child = null;
  }

  @override
  void mount(Element parent, dynamic newSlot) {
    super.mount(parent, newSlot); // Creates the renderObject.
    renderObject.callback = _layout;
  }

  @override
  void update(ConstrainedLayoutBuilder<ConstraintType> newWidget) {
    assert(widget != newWidget);
    super.update(newWidget);
    assert(widget == newWidget);
    renderObject.callback = _layout;
    renderObject.markNeedsLayout();
  }

  @override
  void performRebuild() {
    // This gets called if markNeedsBuild() is called on us.
    // That might happen if, e.g., our builder uses Inherited widgets.
    renderObject.markNeedsLayout();
    super.performRebuild(); // Calls widget.updateRenderObject (a no-op in this case).
  }

  @override
  void unmount() {
    renderObject.callback = null;
    super.unmount();
  }

  void _layout(ConstraintType constraints) {
    owner.buildScope(this, () {
      Widget built;
      if (widget.builder != null) {
        try {
          built = widget.builder(this, constraints);
          debugWidgetBuilderValue(widget, built);
        } catch (e, stack) {
          built = ErrorWidget.builder(_debugReportException(ErrorDescription('building $widget'), e, stack));
        }
      }
      try {
        _child = updateChild(_child, built, null);
        assert(_child != null);
      } catch (e, stack) {
        built = ErrorWidget.builder(_debugReportException(ErrorDescription('building $widget'), e, stack));
        _child = updateChild(null, built, slot);
      }
    });
  }

  @override
  void insertChildRenderObject(RenderObject child, dynamic slot) {
    final RenderObjectWithChildMixin<RenderObject> renderObject = this.renderObject;
    assert(slot == null);
    assert(renderObject.debugValidateChild(child));
    renderObject.child = child;
    assert(renderObject == this.renderObject);
  }

  @override
  void moveChildRenderObject(RenderObject child, dynamic slot) {
    assert(false);
  }

  @override
  void removeChildRenderObject(RenderObject child) {
    final RenderConstrainedLayoutBuilder<ConstraintType, RenderObject> renderObject = this.renderObject;
    assert(renderObject.child == child);
    renderObject.child = null;
    assert(renderObject == this.renderObject);
  }
}

/// Generic mixin for [RenderObject]s created by [ConstrainedLayoutBuilder].
///
/// Provides a callback that should be called at layout time, typically in
/// [RenderObject.performLayout].
mixin RenderConstrainedLayoutBuilder<ConstraintType extends Constraints, ChildType extends RenderObject> on RenderObjectWithChildMixin<ChildType> {
  LayoutCallback<ConstraintType> _callback;
  /// Change the layout callback.
  set callback(LayoutCallback<ConstraintType> value) {
    if (value == _callback)
      return;
    _callback = value;
    markNeedsLayout();
  }

  /// Invoke the layout callback.
  void layoutAndBuildChild() {
    assert(_callback != null);
    invokeLayoutCallback(_callback);
  }
}

/// Builds a widget tree that can depend on the parent widget's size.
///
/// Similar to the [Builder] widget except that the framework calls the [builder]
/// function at layout time and provides the parent widget's constraints. This
/// is useful when the parent constrains the child's size and doesn't depend on
/// the child's intrinsic size. The [LayoutBuilder]'s final size will match its
/// child's size.
///
/// {@youtube 560 315 https://www.youtube.com/watch?v=IYDVcriKjsw}
///
/// If the child should be smaller than the parent, consider wrapping the child
/// in an [Align] widget. If the child might want to be bigger, consider
/// wrapping it in a [SingleChildScrollView].
///
/// See also:
///
///  * [SliverLayoutBuilder], the sliver counterpart of this widget.
///  * [Builder], which calls a `builder` function at build time.
///  * [StatefulBuilder], which passes its `builder` function a `setState` callback.
///  * [CustomSingleChildLayout], which positions its child during layout.
class LayoutBuilder extends ConstrainedLayoutBuilder<BoxConstraints> {
  /// Creates a widget that defers its building until layout.
  ///
  /// The [builder] argument must not be null.
  const LayoutBuilder({
    Key key,
    LayoutWidgetBuilder builder,
  }) : super(key: key, builder: builder);

  @override
  LayoutWidgetBuilder get builder;

  @override
  _RenderLayoutBuilder createRenderObject(BuildContext context) => _RenderLayoutBuilder();
}

class _RenderLayoutBuilder extends RenderBox with RenderObjectWithChildMixin<RenderBox>, RenderConstrainedLayoutBuilder<BoxConstraints, RenderBox> {
  @override
  double computeMinIntrinsicWidth(double height) {
    assert(_debugThrowIfNotCheckingIntrinsics());
    return 0.0;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    assert(_debugThrowIfNotCheckingIntrinsics());
    return 0.0;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    assert(_debugThrowIfNotCheckingIntrinsics());
    return 0.0;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    assert(_debugThrowIfNotCheckingIntrinsics());
    return 0.0;
  }

  @override
  void performLayout() {
    layoutAndBuildChild();
    if (child != null) {
      child.layout(constraints, parentUsesSize: true);
      size = constraints.constrain(child.size);
    } else {
      size = constraints.biggest;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, { Offset position }) {
    return child?.hitTest(result, position: position) ?? false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null)
      context.paintChild(child, offset);
  }

  bool _debugThrowIfNotCheckingIntrinsics() {
    assert(() {
      if (!RenderObject.debugCheckingIntrinsics) {
        throw FlutterError(
          'LayoutBuilder does not support returning intrinsic dimensions.\n'
          'Calculating the intrinsic dimensions would require running the layout '
          'callback speculatively, which might mutate the live render object tree.'
        );
      }
      return true;
    }());

    return true;
  }
}

/// Builds a sliver widget tree that can depend on its own [SliverConstraints].
///
/// Similar to the [LayoutBuilder] widget except its builder should return a sliver
/// widget, and [SliverLayoutBuilder] is itself a sliver. The framework calls the
/// [builder] function at layout time and provides the current [SliverConstraints].
/// The [SliverLayoutBuilder]'s final [SliverGeometry] will match the [SliverGeometry]
/// of its child.
///
///
/// See also:
///
///  * [LayoutBuilder], the non-sliver version of this widget.
class SliverLayoutBuilder extends ConstrainedLayoutBuilder<SliverConstraints> {
  /// Creates a sliver widget that defers its building until layout.
  ///
  /// The [builder] argument must not be null.
  const SliverLayoutBuilder({
    Key key,
    SliverLayoutWidgetBuilder builder,
  }) : super(key: key, builder: builder);

  /// Called at layout time to construct the widget tree. The builder must return
  /// a non-null sliver widget.
  @override
  SliverLayoutWidgetBuilder get builder;

  @override
  _RenderSliverLayoutBuilder createRenderObject(BuildContext context) => _RenderSliverLayoutBuilder();
}

class _RenderSliverLayoutBuilder extends RenderSliver with RenderObjectWithChildMixin<RenderSliver>, RenderConstrainedLayoutBuilder<SliverConstraints, RenderSliver> {
  @override
  double childMainAxisPosition(RenderObject child) {
    assert(child != null);
    assert(child == this.child);
    return 0;
  }

  @override
  void performLayout() {
    layoutAndBuildChild();
    child?.layout(constraints, parentUsesSize: true);
    geometry = child?.geometry ?? SliverGeometry.zero;
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    assert(child != null);
    assert(child == this.child);
    // child's offset is always (0, 0), transform.translate(0, 0) does not mutate the transform.
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // This renderObject does not introduce additional offset to child's position.
    if (child?.geometry?.visible == true)
      context.paintChild(child, offset);
  }

  @override
  bool hitTestChildren(SliverHitTestResult result, {double mainAxisPosition, double crossAxisPosition}) {
    return child != null
        && child.geometry.hitTestExtent > 0
        && child.hitTest(result, mainAxisPosition: mainAxisPosition, crossAxisPosition: crossAxisPosition);
  }
}

FlutterErrorDetails _debugReportException(
  DiagnosticsNode context,
  dynamic exception,
  StackTrace stack,
) {
  final FlutterErrorDetails details = FlutterErrorDetails(
    exception: exception,
    stack: stack,
    library: 'widgets library',
    context: context,
  );
  FlutterError.reportError(details);
  return details;
}
