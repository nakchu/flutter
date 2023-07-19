// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import 'framework.dart';
import 'platform_view.dart';

const String _kDefaultVisibleViewType = '_default_document_create_element_visible';
const String _kDefaultInvisibleViewType = '_default_document_create_element_invisible';

/// The platform-specific implementation of [HtmlElementView].
extension HtmlElementViewImpl on HtmlElementView {
  /// Creates an [HtmlElementView] that renders a DOM element with the given
  /// [tagName].
  static HtmlElementView createFromTagName({
    Key? key,
    required String tagName,
    bool isVisible = true,
    ElementCreatedCallback? onElementCreated,
  }) {
    _registerDefaultFactories();
    return HtmlElementView(
      key: key,
      viewType: isVisible ? _kDefaultVisibleViewType : _kDefaultInvisibleViewType,
      onPlatformViewCreated: _createPlatformViewCallbackForElementCallback(onElementCreated),
      creationParams: <dynamic, dynamic>{'tagName': tagName},
    );
  }

  /// The implementation of [HtmlElementView.build].
  ///
  /// This is not expected to be invoked in non-web environments. It throws if
  /// that happens.
  ///
  /// The implementation on Flutter Web builds an HTML platform view and handles
  /// its lifecycle.
  Widget buildImpl(BuildContext context) {
    return PlatformViewLink(
      viewType: viewType,
      onCreatePlatformView: _createController,
      surfaceFactory: (BuildContext context, PlatformViewController controller) {
        return PlatformViewSurface(
          controller: controller,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        );
      },
    );
  }

  /// Creates the controller and kicks off its initialization.
  _HtmlElementViewController _createController(
    PlatformViewCreationParams params,
  ) {
    final _HtmlElementViewController controller = _HtmlElementViewController(
      params.id,
      viewType,
      creationParams,
    );
    controller._initialize().then((_) {
      params.onPlatformViewCreated(params.id);
      onPlatformViewCreated?.call(params.id);
    });
    return controller;
  }
}

PlatformViewCreatedCallback? _createPlatformViewCallbackForElementCallback(
  ElementCreatedCallback? onElementCreated,
) {
  if (onElementCreated == null) {
    return null;
  }
  return (int id) {
    onElementCreated(_platformViewsRegistry.getViewById(id));
  };
}

class _HtmlElementViewController extends PlatformViewController {
  _HtmlElementViewController(
    this.viewId,
    this.viewType,
    this.creationParams,
  );

  @override
  final int viewId;

  /// The unique identifier for the HTML view type to be embedded by this widget.
  ///
  /// A PlatformViewFactory for this type must have been registered.
  final String viewType;

  final dynamic creationParams;

  bool _initialized = false;

  Future<void> _initialize() async {
    final Map<String, dynamic> args = <String, dynamic>{
      'id': viewId,
      'viewType': viewType,
      'params': creationParams,
    };
    await SystemChannels.platform_views.invokeMethod<void>('create', args);
    _initialized = true;
  }

  @override
  Future<void> clearFocus() async {
    // Currently this does nothing on Flutter Web.
    // TODO(het): Implement this. See https://github.com/flutter/flutter/issues/39496
  }

  @override
  Future<void> dispatchPointerEvent(PointerEvent event) async {
    // We do not dispatch pointer events to HTML views because they may contain
    // cross-origin iframes, which only accept user-generated events.
  }

  @override
  Future<void> dispose() async {
    if (_initialized) {
      await SystemChannels.platform_views.invokeMethod<void>('dispose', viewId);
    }
  }
}

/// Overrides the [ui_web.PlatformViewRegistry] used by [HtmlElementView].
///
/// This is used for testing view factory registration.
@visibleForTesting
ui_web.PlatformViewRegistry? debugOverridePlatformViewRegistry;
ui_web.PlatformViewRegistry get _platformViewsRegistry => debugOverridePlatformViewRegistry ?? ui_web.platformViewRegistry;

bool _areDefaultFactoriesRegistered = false;

/// Reset default view factories so that they are registered again next time.
///
/// There is no way to acually unregister a view factory, so this is only useful
/// during testing when switching to a new [FakePlatformViewRegistry] to make
/// sure the default view factories are re-registered.
@visibleForTesting
void debugResetDefaultFactories() {
  _areDefaultFactoriesRegistered = false;
}

void _registerDefaultFactories() {
  if (_areDefaultFactoriesRegistered) {
    return;
  }

  _platformViewsRegistry.registerViewFactory(
    _kDefaultVisibleViewType,
    _defaultFactory,
  );
  _platformViewsRegistry.registerViewFactory(
    _kDefaultInvisibleViewType,
    _defaultFactory,
    isVisible: false,
  );
}

web.Element _defaultFactory(
  int viewId, {
  Object? params,
}) {
  params!;
  params as _DefaultFactoryParams;
  return web.document.createElement(params.tagName);
}

typedef _DefaultFactoryParams = Map<Object?, Object?>;

extension on _DefaultFactoryParams {
  String get tagName => this['tagName']! as String;
}
