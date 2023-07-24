// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/scheduler.dart';

import 'framework.dart';
import 'navigator.dart';
import 'notification_listener.dart';
import 'pop_scope.dart';

/// Enables the handling of system back gestures.
///
/// Typically wraps a nested [Navigator] widget and allows it to handle system
/// back gestures in the [onPop] callback.
///
/// {@tool dartpad}
/// This sample demonstrates how to use this widget to properly handle system
/// back gestures when using nested [Navigator]s.
///
/// ** See code in examples/api/lib/widgets/navigator_pop_handler/navigator_pop_handler.0.dart **
/// {@end-tool}
///
/// See also:
///
///  * [PopScope], which allows toggling the ability of a [Navigator] to
///    handle pops.
///  * [NavigationNotification], which indicates whether a [Navigator] in a
///    subtree can handle pops.
class NavigatorPopHandler extends StatefulWidget {
  /// Creates an instance of [NavigatorPopHandler].
  const NavigatorPopHandler({
    super.key,
    this.onPop,
    required this.child,
  });

  /// The widget to place below this in the widget tree.
  ///
  /// Typically this is a [Navigator] that will handle the pop when [onPop] is
  /// called.
  final Widget child;

  /// Called when a handleable pop event happens.
  ///
  /// For example, a pop is handleable when a [Navigator] in [child] has
  /// multiple routes on its stack. It's not handleable when it has only a
  /// single route, and so [onPop] will not be called.
  ///
  /// Typically this is used to pop the [Navigator] in [child]. See the sample
  /// code on [NavigatorPopHandler] for a full example of this.
  final VoidCallback? onPop;

  @override
  State<NavigatorPopHandler> createState() => _NavigatorPopHandlerState();
}

class _NavigatorPopHandlerState extends State<NavigatorPopHandler> {
  bool _canPop = true;

  @override
  Widget build(BuildContext context) {
    // When the widget subtree indicates it can handle a pop, disable popping
    // here, so that it can be manually handled in canPop.
    return PopScope(
      canPop: _canPop,
      onPopInvoked: (bool didPop) {
        if (didPop) {
          return;
        }
        widget.onPop?.call();
      },
      // Listen to changes in the navigation stack in the widget subtree.
      child: NotificationListener<NavigationNotification>(
        onNotification: (NavigationNotification notification) {
          // If this subtree cannot handle pop, then set canPop to true so
          // that our PopScope will allow the Navigator higher in the tree to
          // handle the pop instead.
          final bool nextCanPop = !notification.canHandlePop;
          if (nextCanPop != _canPop) {
            // It's possible to receive a NavigationNotification during a build,
            // so wait until the next frame to call setState.
            SchedulerBinding.instance.addPostFrameCallback((Duration timeStamp) {
              if (!mounted) {
                return;
              }
              setState(() {
                _canPop = nextCanPop;
              });
            });
          }
          return false;
        },
        child: widget.child,
      ),
    );
  }
}
