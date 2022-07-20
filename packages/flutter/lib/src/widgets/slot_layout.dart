// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'animated_switcher.dart';
import 'basic.dart';
import 'breakpoint.dart';
import 'framework.dart';
import 'slot_layout_config.dart';
import 'ticker_provider.dart';

/// A Widget that takes a mapping of [SlotLayoutConfig]s to breakpoints and
/// returns a chosen Widget based on the current screen size.
///
/// Commonly used with [AdaptiveLayout] but also functional on its own.

class SlotLayout extends StatefulWidget {
  /// Creates a [SlotLayout] widget.
  const SlotLayout({required this.config, super.key});

  /// Given a context and a config, it returns the [SlotLayoutConfig] that will
  /// be chosen from the config under the context's conditions.
  static SlotLayoutConfig? pickWidget(BuildContext context, Map<Breakpoint, SlotLayoutConfig?> config) {
    SlotLayoutConfig? chosenWidget;
    config.forEach((Breakpoint key, SlotLayoutConfig? value) {
      if (key.isActive(context)) {
        chosenWidget = value;
      }
    });
    return chosenWidget;
  }

  /// The mapping that is used to determine what Widget to display at what point.
  ///
  /// The int represents screen width.
  final Map<Breakpoint, SlotLayoutConfig?> config;
  @override
  State<SlotLayout> createState() => _SlotLayoutState();
}

class _SlotLayoutState extends State<SlotLayout> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  SlotLayoutConfig? chosenWidget;
  ValueNotifier<Key> changedWidget = ValueNotifier<Key>(const Key(''));
  List<Key> animatingWidgets = <Key>[];

  @override
  void initState() {
    changedWidget.addListener(() {
      _controller.reset();
      _controller.forward();
    });

    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..forward();
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    chosenWidget = SlotLayout.pickWidget(context, widget.config);
    bool hasAnimation = false;
    if (chosenWidget != null) {
      changedWidget.value = chosenWidget!.key!;
    } else {
      changedWidget.value = const Key('');
    }
    return AnimatedSwitcher(
        duration: const Duration(milliseconds: 1000),
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          final Stack elements = Stack(
            children: <Widget>[
              if (hasAnimation) ...previousChildren.where((Widget element) => element.key != currentChild!.key),
              if (currentChild != null) currentChild,
            ],
          );
          return elements;
        },
        transitionBuilder: (Widget child, Animation<double> animation) {
          final SlotLayoutConfig configChild = child as SlotLayoutConfig;
          print(configChild.outAnimation);
          if (child.key == chosenWidget?.key) {
            return (configChild.inAnimation != null) ? child.inAnimation!(child, _controller) : child;
          } else {
            if (configChild.outAnimation != null && configChild != null) {
              hasAnimation = true;
            }
            return (configChild.outAnimation != null) ? child.outAnimation!(child, _controller) : child;
          }
        },
        child: chosenWidget ?? SlotLayoutConfig.empty());
  }
}
