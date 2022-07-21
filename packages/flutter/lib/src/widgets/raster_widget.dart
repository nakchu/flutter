// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'basic.dart';
import 'framework.dart';
import 'media_query.dart';

/// A controller for the [RasterWidget] that controls when the child image is displayed
/// and when to regenerated the child image.
///
/// When the value of [rasterize] is true, The [RasterWidget] will convert the child scene into
/// an image. This image will be drawn in place of the children until [rasterize] is false.
/// Any changes to the widget tree that would normally cause it to repaint are ignored.
///
/// To force [RasterWidget] to recreate the child image, call [clear].
class RasterWidgetController extends ChangeNotifier {
  /// Create a new [RasterWidgetController].
  ///
  /// By default, [rasterize] is `false` and cannot be `null`.
  RasterWidgetController({
    bool rasterize = false,
    bool fallback = false,
  }) : _rasterize = rasterize,
       _fallback = fallback;

  /// Reset the raster held by any listening [RasterWidget].
  ///
  /// This has no effect if [rasterize] is `false`.
  void clear() {
    notifyListeners();
  }

  /// Whether a rasterized version of this render objects child is drawn in
  /// place of the child.
  bool get rasterize => _rasterize;
  bool _rasterize;
  set rasterize(bool value) {
    if (value == rasterize) {
      return;
    }
    _rasterize = value;
    notifyListeners();
  }

  /// Whether the raster widget should use the provided [RasterWidgetFallbackDelegate]
  /// to render.
  ///
  /// Defaults to `false`. Generally, this should only be used if it is known
  /// that the current platform does not support the raster widget.
  ///
  /// Setting this to `true` on a raster widget that does not have a fallback
  /// delegate will cause an exception to be thrown.
  bool get fallback => _fallback;
  bool _fallback;
  set fallback(bool value) {
    if (value == fallback) {
      return;
    }
    _fallback = value;
    notifyListeners();
  }
}

/// A widget that replaces its child with a rasterized version of the child.
///
/// By default, the child is drawn as is. The default [delegate] simply scales
/// down the image by the current device pixel ratio and paints it into the
/// canvas. How this image is drawn can be customized by providing a new
/// subclass of [RasterWidgetDelegate] to the [delegate] argument.
///
/// Caveats:
///
/// The contents of platform views cannot be captured by a raster
/// widget. If a platform view is encountered, then by default an error
/// is thrown. If [ignorePlatformViews] is true, the rasterization is used
/// without the platform view included. This may result in an incomplete picture,
/// but may be a reasonable choice if the platform view is only incidentally included
/// in a scene. Alternatively, if a [fallback] is provided and a platform view is
/// detected, then the fallback is used to render the scene instead of the
/// raster. This is only intended for the rare case when a raster widget
/// cannot know if a child will have a platform view.
///
/// This widget is not supported on the HTML backend of Flutter for the web.
class RasterWidget extends SingleChildRenderObjectWidget {
  /// Create a new [RasterWidget].
  ///
  /// The [controller] and [child] arguments are required.
  const RasterWidget({
    super.key,
    this.delegate = const _RasterDefaultDelegate(),
    this.fallback,
    this.ignorePlatformViews = false,
    required this.controller,
    required super.child
  });

  /// A delegate that allows customization of how the image is painted.
  ///
  /// If not provided, defaults to a delegate which paints the child as is.
  final RasterWidgetDelegate delegate;

  /// The controller that determines when to display the children as an image.
  final RasterWidgetController controller;

  /// A fallback delegate which is used if the child layers contains a platform view.
  final RasterWidgetFallbackDelegate? fallback;

  /// Whether the raster widget will ignore platform views in child layers.
  ///
  /// Defaults to `false`, which causes an error to be thrown if a platform view
  /// is encountered.
  final bool ignorePlatformViews;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderRasterWidget(
      delegate: delegate,
      controller: controller,
      fallback: fallback,
      ignorePlatformViews: ignorePlatformViews,
      devicePixelRatio: MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0,
    );
  }

  @override
  void updateRenderObject(BuildContext context, covariant RenderRasterWidget renderObject) {
    renderObject
      ..delegate = delegate
      ..controller = controller
      ..fallback = fallback
      ..ignorePlatformViews = ignorePlatformViews
      ..devicePixelRatio = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
  }
}

/// A delegate which the [RasterWidget] can use to fallback to regular rendering
/// if a platform view is present in the layer tree.
///
/// Consumers of [RasterWidget] should almost never use this delegate. For the most part,
/// the raster widget only functions as a performance improvement. If a platform view is
/// present, the performance improving qualities aren't possible and using this API is
/// pointless.
///
/// Instead, this interface is useful if a generic/reusable widget is being created which
/// may include a platform view and it needs to handle this transparently. For example, the
/// framework uses this for the zoom page transition so that navigating to a page shows the same
/// animation whether or not there is a platform view.
abstract class RasterWidgetFallbackDelegate {
  /// const constructor so that subclasses can be const.
  const RasterWidgetFallbackDelegate();

  /// Paint the child via [painter], applying any effects that would have been painted
  /// with the [RasterWidgetDelegate].
  ///
  /// The [offset] and [size] are the location and dimensions of the render object.
  void paintFallback(PaintingContext context, Offset offset, Size size, PaintingContextCallback painter);
}

/// A delegate used to draw the image representing the rasterized child.
///
/// The delegate can call [notifyListeners] to have the raster widget
/// re-paint (re-using the same raster). This allows animations to be connected
/// to the raster and performed without re-rasterization of children. For
/// certain scale or perspective changing transforms, such as a rotation, this
/// can be significantly faster than performing the same animation at the
/// widget level.
///
/// By default, the [RasterWidget] includes a delegate that draws the child raster
/// exactly as the child widgets would have been drawn. Nevertheless, this can
/// also be used to efficiently transform the child raster and apply complex paint
/// effects.
///
/// {@tool snippet}
///
/// The following method shows how to efficiently rotate the child raster.
///
/// ```dart
/// void paint(PaintingContext context, Offset offset, Size size, ui.Image image, double pixelRatio) {
///   final radians = 0.5; // Could be driven by an animation.
///   final Matrix4 transform = Matrix4.rotationZ(radians);
///   context.canvas.transform(transform.storage);
///   final Rect src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
///   final Rect dst = Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height);
///   final Paint paint = Paint()
///     ..filterQuality = FilterQuality.low;
///   context.canvas.drawImageRect(image, src, dst, paint);
/// }
/// ```
abstract class RasterWidgetDelegate extends ChangeNotifier {
  /// Called whenever the [image] that represents a [RasterWidget]s child should be painted.
  ///
  /// The image is rasterized at the physical pixel resolution and should be scaled down by
  /// [pixelRatio] to account for device independent pixels.
  ///
  /// There is no offset given in this paint method, as the parent is an [OffsetLayer] all
  /// offsets are [Offset.zero].
  ///
  /// {@tool snippet}
  ///
  /// The follow method shows how the default implementation of the delegate used by the
  /// [RasterWidget] paints the child image. This must account for the fact that the image
  /// width and height will be given in physical pixels, while the image must be painted with
  /// device independent pixels. That is, the width and height of the image is the widget and
  /// height of the provided `size`, multiplied by the `pixelRatio`:
  ///
  /// ```dart
  /// void paint(PaintingContext context, Offset offset, Size size, ui.Image image, double pixelRatio) {
  ///   final Rect src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
  ///   final Rect dst = Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height);
  ///   final Paint paint = Paint()
  ///     ..filterQuality = FilterQuality.low;
  ///   context.canvas.drawImageRect(image, src, dst, paint);
  /// }
  /// ```
  /// {@end-tool}
  void paint(PaintingContext context, Offset offset, Size size, ui.Image image, double pixelRatio);

  /// Called whenever a new instance of the raster widget delegate class is
  /// provided to the [RenderRasterWidget] object, or any time that a new
  /// [RasterWidgetDelegate] object is created with a new instance of the
  /// delegate class (which amounts to the same thing, because the latter is
  /// implemented in terms of the former).
  ///
  /// If the new instance represents different information than the old
  /// instance, then the method should return true, otherwise it should return
  /// false.
  ///
  /// If the method returns false, then the [paint] call might be optimized
  /// away.
  ///
  /// It's possible that the [paint] method will get called even if
  /// [shouldRepaint] returns false (e.g. if an ancestor or descendant needed to
  /// be repainted). It's also possible that the [paint] method will get called
  /// without [shouldRepaint] being called at all (e.g. if the box changes
  /// size).
  ///
  /// Changing the delegate will not cause the child image retained by the
  /// [RenderRasterWidget] to be updated. Instead, [RasterWidgetController.clear] can
  /// be used to force the generation of a new image.
  ///
  /// The `oldDelegate` argument will never be null.
  bool shouldRepaint(covariant RasterWidgetDelegate oldDelegate);
}

/// A render object that draws its child as a [ui.Image].
class RenderRasterWidget extends RenderProxyBox {
  /// Create a new [RenderRasterWidget].
  RenderRasterWidget({
    required RasterWidgetDelegate delegate,
    required double devicePixelRatio,
    required RasterWidgetController controller,
    required bool ignorePlatformViews,
    RasterWidgetFallbackDelegate? fallback,
  }) : _delegate = delegate,
       _devicePixelRatio = devicePixelRatio,
       _controller = controller,
       _fallback = fallback,
       _ignorePlatformViews = ignorePlatformViews;

  /// The device pixel ratio used to create the child image.
  double get devicePixelRatio => _devicePixelRatio;
  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value == devicePixelRatio) {
      return;
    }
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  /// Whether a rasterized version of this render objects child is drawn in
  /// place of the child.
  RasterWidgetController get controller => _controller;
  RasterWidgetController _controller;
  set controller(RasterWidgetController value) {
    if (value == controller) {
      return;
    }
    controller.removeListener(_onRasterValueChanged);
    final bool oldValue = controller.rasterize;
    _controller = value;
    if (attached) {
      controller.addListener(_onRasterValueChanged);
      if (oldValue != controller.rasterize) {
        _onRasterValueChanged();
      }
    }
  }

  /// The delegate used to draw the image representing the child.
  RasterWidgetDelegate get delegate => _delegate;
  RasterWidgetDelegate _delegate;
  set delegate(RasterWidgetDelegate value) {
    if (value == delegate) {
      return;
    }
    delegate.removeListener(markNeedsPaint);
    final RasterWidgetDelegate oldDelegate = _delegate;
    _delegate = value;
    if (attached) {
      delegate.addListener(markNeedsPaint);
      if (delegate.shouldRepaint(oldDelegate)) {
        markNeedsPaint();
      }
    }
  }

  /// A fallback delegate which is used if the child layers contains a platform view.
  RasterWidgetFallbackDelegate? get fallback => _fallback;
  RasterWidgetFallbackDelegate? _fallback;
  set fallback(RasterWidgetFallbackDelegate? value) {
    if (value == fallback) {
      return;
    }
    _fallback = value;
    markNeedsPaint();
  }

  /// Whether the raster widget will ignore platform views in child layers.
  bool get ignorePlatformViews => _ignorePlatformViews;
  bool _ignorePlatformViews;
  set ignorePlatformViews(bool value) {
    if (value == ignorePlatformViews) {
      return;
    }
    _ignorePlatformViews = value;
    if (ignorePlatformViews) {
      _hitPlatformView = false;
    }
    markNeedsPaint();
  }

  ui.Image? _childRaster;

  @override
  void attach(covariant PipelineOwner owner) {
    delegate.addListener(markNeedsPaint);
    controller.addListener(_onRasterValueChanged);
    super.attach(owner);
  }

  @override
  void detach() {
    delegate.removeListener(markNeedsPaint);
    controller.removeListener(_onRasterValueChanged);
    _childRaster?.dispose();
    _childRaster = null;
    super.detach();
  }

  @override
  void dispose() {
    delegate.removeListener(markNeedsPaint);
    controller.removeListener(_onRasterValueChanged);
    _childRaster?.dispose();
    _childRaster = null;
    super.dispose();
  }

  void _onRasterValueChanged() {
    _childRaster?.dispose();
    _childRaster = null;
    markNeedsPaint();
  }

  bool _hitPlatformView = false;
  bool get _useFallback => _hitPlatformView || _controller.fallback;

  // Paint [child] with this painting context, then convert to a raster and detach all
  // children from this layer.
  ui.Image? _paintAndDetachToImage() {
    final OffsetLayer offsetLayer = OffsetLayer();
    final PaintingContext context = PaintingContext(offsetLayer, Offset.zero & size);
    super.paint(context, Offset.zero);
    // This ignore is here because this method is protected by the `PaintingContext`. Adding a new
    // method that performs the work of `_paintAndDetachToImage` would avoid the need for this, but
    // that would conflict with our goals of minimizing painting context.
    // ignore: invalid_use_of_protected_member
    context.stopRecordingIfNeeded();
    if (!ignorePlatformViews && !offsetLayer.supportsRasterization()) {
      _hitPlatformView = true;
      if (fallback == null) {
        assert(() {
          throw FlutterError(
            'RasterWidget used with a child that contains a PlatformView.'
          );
        }());
      }
      return null;
    }
    final ui.Image image = offsetLayer.toImageSync(Offset.zero & size, pixelRatio: devicePixelRatio);
    offsetLayer.dispose();
    return image;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) {
      _childRaster?.dispose();
      _childRaster = null;
      return;
    }
    if (controller.rasterize) {
      if (_useFallback) {
        fallback?.paintFallback(context, offset, size, super.paint);
      } else {
        _childRaster ??= _paintAndDetachToImage();
        if (_childRaster == null && _useFallback) {
          fallback?.paintFallback(context, offset, size, super.paint);
        } else {
          delegate.paint(context, offset, size, _childRaster!, devicePixelRatio);
        }
      }
      return;
    }
    _childRaster?.dispose();
    _childRaster = null;
    super.paint(context, offset);
  }
}

// A delegate that paints the child widget as is.
class _RasterDefaultDelegate implements RasterWidgetDelegate {
  const _RasterDefaultDelegate();

  @override
  void paint(PaintingContext context, Offset offset, Size size, ui.Image image, double pixelRatio) {
    final Rect src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final Rect dst = Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height);
    final Paint paint = Paint()
      ..filterQuality = FilterQuality.low;
    context.canvas.drawImageRect(image, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant RasterWidgetDelegate oldDelegate) => false;

  @override
  void addListener(ui.VoidCallback listener) { }

  @override
  void dispose() { }

  @override
  bool get hasListeners => false;

  @override
  void notifyListeners() { }

  @override
  void removeListener(ui.VoidCallback listener) { }
}
