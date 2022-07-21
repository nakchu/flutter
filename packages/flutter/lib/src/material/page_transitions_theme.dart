// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'colors.dart';
import 'theme.dart';

// Slides the page upwards and fades it in, starting from 1/4 screen
// below the top. The transition is intended to match the default for
// Android O.
class _FadeUpwardsPageTransition extends StatelessWidget {
  _FadeUpwardsPageTransition({
    required Animation<double> routeAnimation, // The route's linear 0.0 - 1.0 animation.
    required this.child,
  }) : _positionAnimation = routeAnimation.drive(_bottomUpTween.chain(_fastOutSlowInTween)),
       _opacityAnimation = routeAnimation.drive(_easeInTween);

  // Fractional offset from 1/4 screen below the top to fully on screen.
  static final Tween<Offset> _bottomUpTween = Tween<Offset>(
    begin: const Offset(0.0, 0.25),
    end: Offset.zero,
  );
  static final Animatable<double> _fastOutSlowInTween = CurveTween(curve: Curves.fastOutSlowIn);
  static final Animatable<double> _easeInTween = CurveTween(curve: Curves.easeIn);

  final Animation<Offset> _positionAnimation;
  final Animation<double> _opacityAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _positionAnimation,
      // TODO(ianh): tell the transform to be un-transformed for hit testing
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: child,
      ),
    );
  }
}

// This transition is intended to match the default for Android P.
class _OpenUpwardsPageTransition extends StatelessWidget {
  const _OpenUpwardsPageTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  // The new page slides upwards just a little as its clip
  // rectangle exposes the page from bottom to top.
  static final Tween<Offset> _primaryTranslationTween = Tween<Offset>(
    begin: const Offset(0.0, 0.05),
    end: Offset.zero,
  );

  // The old page slides upwards a little as the new page appears.
  static final Tween<Offset> _secondaryTranslationTween = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(0.0, -0.025),
  );

  // The scrim obscures the old page by becoming increasingly opaque.
  static final Tween<double> _scrimOpacityTween = Tween<double>(
    begin: 0.0,
    end: 0.25,
  );

  // Used by all of the transition animations.
  static const Curve _transitionCurve = Cubic(0.20, 0.00, 0.00, 1.00);

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = constraints.biggest;

        final CurvedAnimation primaryAnimation = CurvedAnimation(
          parent: animation,
          curve: _transitionCurve,
          reverseCurve: _transitionCurve.flipped,
        );

        // Gradually expose the new page from bottom to top.
        final Animation<double> clipAnimation = Tween<double>(
          begin: 0.0,
          end: size.height,
        ).animate(primaryAnimation);

        final Animation<double> opacityAnimation = _scrimOpacityTween.animate(primaryAnimation);
        final Animation<Offset> primaryTranslationAnimation = _primaryTranslationTween.animate(primaryAnimation);

        final Animation<Offset> secondaryTranslationAnimation = _secondaryTranslationTween.animate(
          CurvedAnimation(
            parent: secondaryAnimation,
            curve: _transitionCurve,
            reverseCurve: _transitionCurve.flipped,
          ),
        );

        return AnimatedBuilder(
          animation: animation,
          builder: (BuildContext context, Widget? child) {
            return Container(
              color: Colors.black.withOpacity(opacityAnimation.value),
              alignment: Alignment.bottomLeft,
              child: ClipRect(
                child: SizedBox(
                  height: clipAnimation.value,
                  child: OverflowBox(
                    alignment: Alignment.bottomLeft,
                    maxHeight: size.height,
                    child: child,
                  ),
                ),
              ),
            );
          },
          child: AnimatedBuilder(
            animation: secondaryAnimation,
            child: FractionalTranslation(
              translation: primaryTranslationAnimation.value,
              child: child,
            ),
            builder: (BuildContext context, Widget? child) {
              return FractionalTranslation(
                translation: secondaryTranslationAnimation.value,
                child: child,
              );
            },
          ),
        );
      },
    );
  }
}

// Zooms and fades a new page in, zooming out the previous page. This transition
// is designed to match the Android Q activity transition.
class _ZoomPageTransition extends StatelessWidget {
  /// Creates a [_ZoomPageTransition].
  ///
  /// The [animation] and [secondaryAnimation] argument are required and must
  /// not be null.
  const _ZoomPageTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.preferRasterization,
    this.child,
  }) : assert(animation != null),
       assert(secondaryAnimation != null);

  // A curve sequence that is similar to the 'fastOutExtraSlowIn' curve used in
  // the native transition.
  static final List<TweenSequenceItem<double>> fastOutExtraSlowInTweenSequenceItems = <TweenSequenceItem<double>>[
    TweenSequenceItem<double>(
      tween: Tween<double>(begin: 0.0, end: 0.4)
        .chain(CurveTween(curve: const Cubic(0.05, 0.0, 0.133333, 0.06))),
      weight: 0.166666,
    ),
    TweenSequenceItem<double>(
      tween: Tween<double>(begin: 0.4, end: 1.0)
        .chain(CurveTween(curve: const Cubic(0.208333, 0.82, 0.25, 1.0))),
      weight: 1.0 - 0.166666,
    ),
  ];
  static final TweenSequence<double> _scaleCurveSequence = TweenSequence<double>(fastOutExtraSlowInTweenSequenceItems);

  /// The animation that drives the [child]'s entrance and exit.
  ///
  /// See also:
  ///
  ///  * [TransitionRoute.animation], which is the value given to this property
  ///    when the [_ZoomPageTransition] is used as a page transition.
  final Animation<double> animation;

  /// The animation that transitions [child] when new content is pushed on top
  /// of it.
  ///
  /// See also:
  ///
  ///  * [TransitionRoute.secondaryAnimation], which is the value given to this
  ///    property when the [_ZoomPageTransition] is used as a page transition.
  final Animation<double> secondaryAnimation;

  /// Whether the [RasterWidget] based-rasterized strategy for the zoom page transition
  /// will be used.
  ///
  /// Notably, this improves performance by disabling animations on both the outgoing and
  /// incoming route. This also implies that ink-splashes or similar animations will
  /// not animate during the transition.
  final bool preferRasterization;

  /// The widget below this widget in the tree.
  ///
  /// This widget will transition in and out as driven by [animation] and
  /// [secondaryAnimation].
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DualTransitionBuilder(
      animation: animation,
      forwardBuilder: (
        BuildContext context,
        Animation<double> animation,
        Widget? child,
      ) {
        return _ZoomEnterTransition(
          animation: animation,
          preferRasterization: preferRasterization,
          child: child,
        );
      },
      reverseBuilder: (
        BuildContext context,
        Animation<double> animation,
        Widget? child,
      ) {
        return _ZoomExitTransition(
          animation: animation,
          preferRasterization: preferRasterization,
          reverse: true,
          child: child,
        );
      },
      child: DualTransitionBuilder(
        animation: ReverseAnimation(secondaryAnimation),
        forwardBuilder: (
          BuildContext context,
          Animation<double> animation,
          Widget? child,
        ) {
          return _ZoomEnterTransition(
            animation: animation,
            preferRasterization: preferRasterization,
            reverse: true,
            child: child,
          );
        },
        reverseBuilder: (
          BuildContext context,
          Animation<double> animation,
          Widget? child,
        ) {
          return _ZoomExitTransition(
            animation: animation,
            preferRasterization: preferRasterization,
            child: child,
          );
        },
        child: child,
      ),
    );
  }
}

class _ZoomEnterTransition extends StatefulWidget {
  const _ZoomEnterTransition({
    required this.animation,
    this.reverse = false,
    required this.preferRasterization,
    this.child,
  }) : assert(animation != null),
       assert(reverse != null);

  final Animation<double> animation;
  final Widget? child;
  final bool preferRasterization;
  final bool reverse;

  @override
  State<_ZoomEnterTransition> createState() => _ZoomEnterTransitionState();
}

class _ZoomEnterTransitionState extends State<_ZoomEnterTransition> with _ZoomTransitionBase {
  // TODO(jonahwilliams): https://github.com/flutter/flutter/issues/106689
  @override
  bool get allowRasterization => !kIsWeb && widget.preferRasterization;

  late _ZoomEnterTransitionDelegate delegate;

  static final Animatable<double> _fadeInTransition = Tween<double>(
    begin: 0.0,
    end: 1.00,
  ).chain(CurveTween(curve: const Interval(0.125, 0.250)));

  static final Animatable<double> _scaleDownTransition = Tween<double>(
    begin: 1.10,
    end: 1.00,
  ).chain(_ZoomPageTransition._scaleCurveSequence);

  static final Animatable<double> _scaleUpTransition = Tween<double>(
    begin: 0.85,
    end: 1.00,
  ).chain(_ZoomPageTransition._scaleCurveSequence);

  static final Animatable<double?> _scrimOpacityTween = Tween<double?>(
    begin: 0.0,
    end: 0.60,
  ).chain(CurveTween(curve: const Interval(0.2075, 0.4175)));

  void _updateAnimations() {
    fadeTransition = widget.reverse
      ? kAlwaysCompleteAnimation
      : _fadeInTransition.animate(widget.animation);

    scaleTransition = (widget.reverse
        ? _scaleDownTransition
        : _scaleUpTransition
      ).animate(widget.animation);

    widget.animation.addListener(onAnimationValueChange);
    widget.animation.addStatusListener(onAnimationStatusChange);
  }

  @override
  void initState() {
    _updateAnimations();
    delegate = _ZoomEnterTransitionDelegate(
      reverse: widget.reverse,
      fade: fadeTransition,
      scale: scaleTransition,
      animation: widget.animation,
    );
    controller.fallback = !allowRasterization;
    super.initState();
  }

  @override
  void didUpdateWidget(covariant _ZoomEnterTransition oldWidget) {
    if (oldWidget.reverse != widget.reverse || oldWidget.animation != widget.animation) {
      oldWidget.animation.removeListener(onAnimationValueChange);
      oldWidget.animation.removeStatusListener(onAnimationStatusChange);
      _updateAnimations();
      delegate.dispose();
      delegate = _ZoomEnterTransitionDelegate(
        reverse: widget.reverse,
        fade: fadeTransition,
        scale: scaleTransition,
        animation: widget.animation,
      );
    }
    controller.fallback = !allowRasterization;
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    widget.animation.removeListener(onAnimationValueChange);
    widget.animation.removeStatusListener(onAnimationStatusChange);
    delegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RasterWidget(
      delegate: delegate,
      controller: controller,
      fallback: delegate,
      child: widget.child,
    );
  }
}

class _ZoomExitTransition extends StatefulWidget {
  const _ZoomExitTransition({
    required this.animation,
    this.reverse = false,
    required this.preferRasterization,
    this.child,
  }) : assert(animation != null),
       assert(reverse != null);

  final Animation<double> animation;
  final bool preferRasterization;
  final bool reverse;
  final Widget? child;

  @override
  State<_ZoomExitTransition> createState() => _ZoomExitTransitionState();
}

class _ZoomExitTransitionState extends State<_ZoomExitTransition> with _ZoomTransitionBase {
  late _ZoomExitTransitionDelegate delegate;

  // TODO(jonahwilliams): https://github.com/flutter/flutter/issues/106689
  @override
  bool get allowRasterization => !kIsWeb && widget.preferRasterization;

  static final Animatable<double> _fadeOutTransition = Tween<double>(
    begin: 1.0,
    end: 0.0,
  ).chain(CurveTween(curve: const Interval(0.0825, 0.2075)));

  static final Animatable<double> _scaleUpTransition = Tween<double>(
    begin: 1.00,
    end: 1.05,
  ).chain(_ZoomPageTransition._scaleCurveSequence);

  static final Animatable<double> _scaleDownTransition = Tween<double>(
    begin: 1.00,
    end: 0.90,
  ).chain(_ZoomPageTransition._scaleCurveSequence);

  void _updateAnimations() {
    fadeTransition = widget.reverse
      ? _fadeOutTransition.animate(widget.animation)
      : kAlwaysCompleteAnimation;
    scaleTransition = (widget.reverse
      ? _scaleDownTransition
      : _scaleUpTransition
    ).animate(widget.animation);

    widget.animation.addListener(onAnimationValueChange);
    widget.animation.addStatusListener(onAnimationStatusChange);
  }

  @override
  void initState() {
    _updateAnimations();
    delegate = _ZoomExitTransitionDelegate(
      reverse: widget.reverse,
      fade: fadeTransition,
      scale: scaleTransition,
    );
    controller.fallback = !allowRasterization;
    super.initState();
  }

  @override
  void didUpdateWidget(covariant _ZoomExitTransition oldWidget) {
    if (oldWidget.reverse != widget.reverse || oldWidget.animation != widget.animation) {
      oldWidget.animation.removeListener(onAnimationValueChange);
      oldWidget.animation.removeStatusListener(onAnimationStatusChange);
      _updateAnimations();
      delegate.dispose();
      delegate = _ZoomExitTransitionDelegate(
        reverse: widget.reverse,
        fade: fadeTransition,
        scale: scaleTransition,
      );
    }
    controller.fallback = !allowRasterization;
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    widget.animation.removeListener(onAnimationValueChange);
    widget.animation.removeStatusListener(onAnimationStatusChange);
    delegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RasterWidget(
      delegate: delegate,
      controller: controller,
      fallback: delegate,
      child: widget.child,
    );
  }
}

/// Used by [PageTransitionsTheme] to define a [MaterialPageRoute] page
/// transition animation.
///
/// Apps can configure the map of builders for [ThemeData.pageTransitionsTheme]
/// to customize the default [MaterialPageRoute] page transition animation
/// for different platforms.
///
/// See also:
///
///  * [FadeUpwardsPageTransitionsBuilder], which defines a page transition
///    that's similar to the one provided by Android O.
///  * [OpenUpwardsPageTransitionsBuilder], which defines a page transition
///    that's similar to the one provided by Android P.
///  * [ZoomPageTransitionsBuilder], which defines the default page transition
///    that's similar to the one provided in Android Q.
///  * [CupertinoPageTransitionsBuilder], which defines a horizontal page
///    transition that matches native iOS page transitions.
abstract class PageTransitionsBuilder {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const PageTransitionsBuilder();

  /// Wraps the child with one or more transition widgets which define how [route]
  /// arrives on and leaves the screen.
  ///
  /// The [MaterialPageRoute.buildTransitions] method looks up the
  /// current [PageTransitionsTheme] with `Theme.of(context).pageTransitionsTheme`
  /// and delegates to this method with a [PageTransitionsBuilder] based
  /// on the theme's [ThemeData.platform].
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  );
}

/// Used by [PageTransitionsTheme] to define a vertically fading
/// [MaterialPageRoute] page transition animation that looks like
/// the default page transition used on Android O.
///
/// The animation fades the new page in while translating it upwards,
/// starting from about 25% below the top of the screen.
///
/// See also:
///
///  * [OpenUpwardsPageTransitionsBuilder], which defines a page transition
///    that's similar to the one provided by Android P.
///  * [ZoomPageTransitionsBuilder], which defines the default page transition
///    that's similar to the one provided in Android Q.
///  * [CupertinoPageTransitionsBuilder], which defines a horizontal page
///    transition that matches native iOS page transitions.
class FadeUpwardsPageTransitionsBuilder extends PageTransitionsBuilder {
  /// Constructs a page transition animation that slides the page up.
  const FadeUpwardsPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double>? secondaryAnimation,
    Widget child,
  ) {
    return _FadeUpwardsPageTransition(routeAnimation: animation, child: child);
  }
}

/// Used by [PageTransitionsTheme] to define a vertical [MaterialPageRoute] page
/// transition animation that looks like the default page transition
/// used on Android P.
///
/// See also:
///
///  * [FadeUpwardsPageTransitionsBuilder], which defines a page transition
///    that's similar to the one provided by Android O.
///  * [ZoomPageTransitionsBuilder], which defines the default page transition
///    that's similar to the one provided in Android Q.
///  * [CupertinoPageTransitionsBuilder], which defines a horizontal page
///    transition that matches native iOS page transitions.
class OpenUpwardsPageTransitionsBuilder extends PageTransitionsBuilder {
  /// Constructs a page transition animation that matches the transition used on
  /// Android P.
  const OpenUpwardsPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _OpenUpwardsPageTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

/// Used by [PageTransitionsTheme] to define a zooming [MaterialPageRoute] page
/// transition animation that looks like the default page transition used on
/// Android Q.
///
/// See also:
///
///  * [FadeUpwardsPageTransitionsBuilder], which defines a page transition
///    that's similar to the one provided by Android O.
///  * [OpenUpwardsPageTransitionsBuilder], which defines a page transition
///    that's similar to the one provided by Android P.
///  * [CupertinoPageTransitionsBuilder], which defines a horizontal page
///    transition that matches native iOS page transitions.
class ZoomPageTransitionsBuilder extends PageTransitionsBuilder {
  /// Constructs a page transition animation that matches the transition used on
  /// Android Q.
  const ZoomPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget? child,
  ) {
    return _ZoomPageTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      preferRasterization: route?.preferRasterization ?? true,
      child: child,
    );
  }
}

/// Used by [PageTransitionsTheme] to define a horizontal [MaterialPageRoute]
/// page transition animation that matches native iOS page transitions.
///
/// See also:
///
///  * [FadeUpwardsPageTransitionsBuilder], which defines a page transition
///    that's similar to the one provided by Android O.
///  * [OpenUpwardsPageTransitionsBuilder], which defines a page transition
///    that's similar to the one provided by Android P.
///  * [ZoomPageTransitionsBuilder], which defines the default page transition
///    that's similar to the one provided in Android Q.
class CupertinoPageTransitionsBuilder extends PageTransitionsBuilder {
  /// Constructs a page transition animation that matches the iOS transition.
  const CupertinoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return CupertinoRouteTransitionMixin.buildPageTransitions<T>(route, context, animation, secondaryAnimation, child);
  }
}

/// Defines the page transition animations used by [MaterialPageRoute]
/// for different [TargetPlatform]s.
///
/// The [MaterialPageRoute.buildTransitions] method looks up the
/// current [PageTransitionsTheme] with `Theme.of(context).pageTransitionsTheme`
/// and delegates to [buildTransitions].
///
/// If a builder with a matching platform is not found, then the
/// [FadeUpwardsPageTransitionsBuilder] is used.
///
/// See also:
///
///  * [ThemeData.pageTransitionsTheme], which defines the default page
///    transitions for the overall theme.
///  * [FadeUpwardsPageTransitionsBuilder], which defines a page transition
///    that's similar to the one provided by Android O.
///  * [OpenUpwardsPageTransitionsBuilder], which defines a page transition
///    that's similar to the one provided by Android P.
///  * [ZoomPageTransitionsBuilder], which defines the default page transition
///    that's similar to the one provided by Android Q.
///  * [CupertinoPageTransitionsBuilder], which defines a horizontal page
///    transition that matches native iOS page transitions.
@immutable
class PageTransitionsTheme with Diagnosticable {
  /// Constructs an object that selects a transition based on the platform.
  ///
  /// By default the list of builders is: [ZoomPageTransitionsBuilder]
  /// for [TargetPlatform.android], and [CupertinoPageTransitionsBuilder] for
  /// [TargetPlatform.iOS] and [TargetPlatform.macOS].
  const PageTransitionsTheme({ Map<TargetPlatform, PageTransitionsBuilder> builders = _defaultBuilders }) : _builders = builders;

  static const Map<TargetPlatform, PageTransitionsBuilder> _defaultBuilders = <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: ZoomPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
  };

  /// The [PageTransitionsBuilder]s supported by this theme.
  Map<TargetPlatform, PageTransitionsBuilder> get builders => _builders;
  final Map<TargetPlatform, PageTransitionsBuilder> _builders;

  /// Delegates to the builder for the current [ThemeData.platform]
  /// or [ZoomPageTransitionsBuilder].
  ///
  /// [MaterialPageRoute.buildTransitions] delegates to this method.
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    TargetPlatform platform = Theme.of(context).platform;

    if (CupertinoRouteTransitionMixin.isPopGestureInProgress(route)) {
      platform = TargetPlatform.iOS;
    }

    final PageTransitionsBuilder matchingBuilder =
      builders[platform] ?? const ZoomPageTransitionsBuilder();
    return matchingBuilder.buildTransitions<T>(route, context, animation, secondaryAnimation, child);
  }

  // Just used to the builders Map to a list with one PageTransitionsBuilder per platform
  // for the operator == overload.
  List<PageTransitionsBuilder?> _all(Map<TargetPlatform, PageTransitionsBuilder> builders) {
    return TargetPlatform.values.map((TargetPlatform platform) => builders[platform]).toList();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    if (other is PageTransitionsTheme && identical(builders, other.builders)) {
      return true;
    }
    return other is PageTransitionsTheme
        && listEquals<PageTransitionsBuilder?>(_all(other.builders), _all(builders));
  }

  @override
  int get hashCode => Object.hashAll(_all(builders));

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<Map<TargetPlatform, PageTransitionsBuilder>>(
        'builders',
        builders,
        defaultValue: PageTransitionsTheme._defaultBuilders,
      ),
    );
  }
}

// Take an image and draw it centered and scaled. The image is already scaled by the [pixelRatio].
void _drawImageScaledAndCentered(PaintingContext context, ui.Image image, double scale, double opacity, double pixelRatio) {
  if (scale <= 0.0 || opacity <= 0.0) {
    return;
  }
  final Paint paint = Paint()
    ..filterQuality = ui.FilterQuality.low
    ..color = Color.fromRGBO(0, 0, 0, opacity);
  final double logicalWidth = image.width / pixelRatio;
  final double logicalHeight = image.height / pixelRatio;
  final double scaledLogicalWidth = logicalWidth * scale;
  final double scaledLogicalHeight = logicalHeight * scale;
  final double left = (logicalWidth - scaledLogicalWidth) / 2;
  final double top = (logicalHeight - scaledLogicalHeight) / 2;
  final Rect dst = Rect.fromLTWH(left, top, scaledLogicalWidth, scaledLogicalHeight);
  context.canvas.drawImageRect(image, Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()), dst, paint);
}

void _updateScaledTransform(Matrix4 transform, double scale, Size size) {
  transform.setIdentity();
  if (scale == 1.0) {
    return;
  }
  transform.scale(scale, scale);
  final double dx = ((size.width * scale) - size.width) / 2;
  final double dy = ((size.height * scale) - size.height) / 2;
  transform.translate(-dx, -dy);
}

mixin _ZoomTransitionBase {
  // Don't rasterize if:
  // 1. Rasterization is disabled by the platform.
  // 2. The animation is paused/stopped.
  // 3. The values of the scale/fade transition do not
  //    benefit from rasterization.
  final RasterWidgetController controller = RasterWidgetController();

  late Animation<double> fadeTransition;
  late Animation<double> scaleTransition;

  bool get allowRasterization;

  void onAnimationValueChange() {
    if ((scaleTransition.value == 1.0) &&
        (fadeTransition.value == 0.0 ||
         fadeTransition.value == 1.0)) {
        controller.rasterize = false;
      } else {
        controller.rasterize = true;
      }
  }

  void onAnimationStatusChange(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.dismissed:
      case AnimationStatus.completed:
        controller.rasterize = false;
        break;
      case AnimationStatus.forward:
      case AnimationStatus.reverse:
        controller.rasterize = true;
        break;
    }
  }
}

class _ZoomEnterTransitionDelegate extends RasterWidgetDelegate implements RasterWidgetFallbackDelegate {
  _ZoomEnterTransitionDelegate({
    required this.reverse,
    required this.scale,
    required this.fade,
    required this.animation,
  }) {
    animation.addListener(notifyListeners);
    scale.addListener(notifyListeners);
    fade.addListener(notifyListeners);
  }

  final bool reverse;
  final Animation<double> animation;
  final Animation<double> scale;
  final Animation<double> fade;

  final Matrix4 _transform = Matrix4.zero();
  final LayerHandle<OpacityLayer> _opacityHandle = LayerHandle<OpacityLayer>();
  final LayerHandle<TransformLayer> _transformHandler = LayerHandle<TransformLayer>();

  void _drawScrim(PaintingContext context, Offset offset, Size size) {
    double scrimOpacity = 0.0;
    // The transition's scrim opacity only increases on the forward transition.
    // In the reverse transition, the opacity should always be 0.0.
    //
    // Therefore, we need to only apply the scrim opacity animation when
    // the transition is running forwards.
    //
    // The reason that we check that the animation's status is not `completed`
    // instead of checking that it is `forward` is that this allows
    // the interrupted reversal of the forward transition to smoothly fade
    // the scrim away. This prevents a disjointed removal of the scrim.
    if (!reverse && animation.status != AnimationStatus.completed) {
      scrimOpacity = _ZoomEnterTransitionState._scrimOpacityTween.evaluate(animation)!;
    }
    assert(!reverse || scrimOpacity == 0.0);
    if (scrimOpacity > 0.0) {
      context.canvas.drawRect(
        offset & size,
        Paint()..color = Colors.black.withOpacity(scrimOpacity),
      );
    }
  }

  @override
  void paintFallback(PaintingContext context, ui.Offset offset, Size size, PaintingContextCallback painter) {
    _drawScrim(context, offset, size);
    _updateScaledTransform(_transform, scale.value, size);
    _transformHandler.layer = context.pushTransform(true, offset, _transform, (PaintingContext context, Offset offset) {
      _opacityHandle.layer = context.pushOpacity(offset, (fade.value * 255).round(), painter, oldLayer: _opacityHandle.layer);
    }, oldLayer: _transformHandler.layer);
  }

  @override
  void paint(PaintingContext context, Offset offset, Size size, ui.Image image, double pixelRatio) {
    _drawScrim(context, offset, size);
    _drawImageScaledAndCentered(context, image, scale.value, fade.value, pixelRatio);
  }

  @override
  void dispose() {
    animation.removeListener(notifyListeners);
    scale.removeListener(notifyListeners);
    fade.removeListener(notifyListeners);
    _opacityHandle.layer = null;
    _transformHandler.layer = null;
    super.dispose();
  }

  @override
  bool shouldRepaint(covariant _ZoomEnterTransitionDelegate oldDelegate) {
    return oldDelegate.reverse != reverse
      || oldDelegate.animation.value != animation.value
      || oldDelegate.scale.value != scale.value
      || oldDelegate.fade.value != fade.value;
  }
}

class _ZoomExitTransitionDelegate extends RasterWidgetDelegate implements RasterWidgetFallbackDelegate {
  _ZoomExitTransitionDelegate({
    required this.reverse,
    required this.scale,
    required this.fade,
  }) {
    scale.addListener(notifyListeners);
    fade.addListener(notifyListeners);
  }

  final bool reverse;
  final Animation<double> scale;
  final Animation<double> fade;
  final Matrix4 _transform = Matrix4.zero();
  final LayerHandle<OpacityLayer> _opacityHandle = LayerHandle<OpacityLayer>();
  final LayerHandle<TransformLayer> _transformHandler = LayerHandle<TransformLayer>();

  @override
  void paint(PaintingContext context, Offset offset, Size size, ui.Image image, double pixelRatio) {
    _drawImageScaledAndCentered(context, image, scale.value, fade.value, pixelRatio);
  }

  @override
  void paintFallback(PaintingContext context, ui.Offset offset, Size size, PaintingContextCallback painter) {
    _updateScaledTransform(_transform, scale.value, size);
    _transformHandler.layer = context.pushTransform(true, offset, _transform, (PaintingContext context, Offset offset) {
      _opacityHandle.layer = context.pushOpacity(offset, (fade.value * 255).round(), painter, oldLayer: _opacityHandle.layer);
    }, oldLayer: _transformHandler.layer);
  }

  @override
  bool shouldRepaint(covariant _ZoomExitTransitionDelegate oldDelegate) {
    return oldDelegate.reverse != reverse || oldDelegate.fade.value != fade.value || oldDelegate.scale.value != scale.value;
  }

  @override
  void dispose() {
    _opacityHandle.layer = null;
    _transformHandler.layer = null;
    scale.removeListener(notifyListeners);
    fade.removeListener(notifyListeners);
    super.dispose();
  }
}
