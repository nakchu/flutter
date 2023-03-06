// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/services.dart';

import 'framework.dart';
import 'navigator.dart';
import 'routes.dart';

// TODO(justinmc): Document that this can't be set at the time of onPopCallback. Too late.
/// Registers a callback to veto attempts by the user to dismiss the enclosing
/// [ModalRoute].
///
/// {@tool dartpad}
/// Whenever the back button is pressed, you will get a callback at [onWillPop],
/// which returns a [Future]. If the [Future] returns true, the screen is
/// popped.
///
/// ** See code in examples/api/lib/widgets/will_pop_scope/will_pop_scope.0.dart **
/// {@end-tool}
///
/// See also:
///
///  * [ModalRoute.addScopedWillPopCallback] and [ModalRoute.removeScopedWillPopCallback],
///    which this widget uses to register and unregister [onWillPop].
///  * [Form], which provides an `onWillPop` callback that enables the form
///    to veto a `pop` initiated by the app's back button.
///
class WillPopScope extends StatefulWidget {
  /// Creates a widget that registers a callback to veto attempts by the user to
  /// dismiss the enclosing [ModalRoute].
  ///
  /// The [child] argument must not be null.
  const WillPopScope({
    super.key,
    required this.child,
    required this.canPop,
  });

  /// The widget below this widget in the tree.
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget child;

  /// When false, blocks the current route from being popped.
  ///
  /// This includes the root route, where upon popping, the Flutter app would
  /// exit.
  ///
  /// If multiple CanPopScope widgets appear in the widget tree, then each and
  /// every `canPop` must be `true` in order for the route to be able to pop.
  ///
  /// This may have implications for route transitions that allow some
  /// interaction before committing to popping the route. For example,
  /// [Android's predictive back](https://developer.android.com/guide/navigation/predictive-back-gesture)
  /// feature will not animate at all when this boolean is true.
  final bool canPop;

  @override
  State<WillPopScope> createState() => _WillPopScopeState();
}

class _WillPopScopeState extends State<WillPopScope> {
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    // TODO(justinmc): Need to make sure this doesn't conflict with the
    // navigator changing this. Maybe needs to look up in the widget tree.
    SystemNavigator.updateNavigationStackStatus(!widget.canPop);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.onWillPop != null) {
      _route?.removeScopedWillPopCallback(widget.onWillPop!);
    }
    _route = ModalRoute.of(context);
    if (widget.onWillPop != null) {
      _route?.addScopedWillPopCallback(widget.onWillPop!);
    }
  }

  @override
  void didUpdateWidget(WillPopScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onWillPop != oldWidget.onWillPop && _route != null) {
      if (oldWidget.onWillPop != null) {
        _route!.removeScopedWillPopCallback(oldWidget.onWillPop!);
      }
      if (widget.onWillPop != null) {
        _route!.addScopedWillPopCallback(widget.onWillPop!);
      }
    }
  }

  @override
  void dispose() {
    if (widget.onWillPop != null) {
      _route?.removeScopedWillPopCallback(widget.onWillPop!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

