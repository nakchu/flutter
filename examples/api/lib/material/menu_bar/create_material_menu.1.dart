// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Flutter code sample for [createMaterialMenu].

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const ContextMenuApp());

/// An enhanced enum to define the available menus and their shortcuts.
///
/// Using an enum for menu definition is not required, but this illustrates how
/// they could be used for simple menu systems.
enum MenuEntry {
  about('About'),
  showMessage('Show Message', SingleActivator(LogicalKeyboardKey.keyS, control: true)),
  resetMessage('Reset Message', SingleActivator(LogicalKeyboardKey.escape)),
  hideMessage('Hide Message'),
  colorMenu('Color Menu'),
  colorRed('Red Background', SingleActivator(LogicalKeyboardKey.keyR, control: true)),
  colorGreen('Green Background', SingleActivator(LogicalKeyboardKey.keyG, control: true)),
  colorBlue('Blue Background', SingleActivator(LogicalKeyboardKey.keyB, control: true));

  const MenuEntry(this.label, [this.shortcut]);
  final String label;
  final MenuSerializableShortcut? shortcut;
}

class ContextMenuApp extends StatelessWidget {
  const ContextMenuApp({super.key});

  static const String kMessage = '"Talk less. Smile more." - A. Burr';

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: MyContextMenu(message: kMessage)),
    );
  }
}

class MyContextMenu extends StatefulWidget {
  const MyContextMenu({super.key, required this.message});

  final String message;

  @override
  State<MyContextMenu> createState() => _MyContextMenuState();
}

class _MyContextMenuState extends State<MyContextMenu> {
  MenuEntry? _lastSelection;
  final FocusNode _buttonFocusNode = FocusNode(debugLabel: 'Menu Button');
  late MenuHandle _menuHandle;
  ShortcutRegistryEntry? _shortcutsEntry;

  void _updateMenu() {
    _menuHandle = createMaterialMenu(
      buttonFocusNode: _buttonFocusNode,
      children: <Widget>[
        MenuItemButton(
          child: Text(MenuEntry.about.label),
          onPressed: () => _activate(MenuEntry.about),
        ),
        // Toggles the message.
        MenuItemButton(
          onPressed: () => _activate(MenuEntry.showMessage),
          shortcut: MenuEntry.showMessage.shortcut,
          child: Text(
            showingMessage ? MenuEntry.hideMessage.label : MenuEntry.showMessage.label,
          ),
        ),
        // Hides the message, but is only enabled if the message isn't already
        // hidden.
        MenuItemButton(
          onPressed: showingMessage ? () => _activate(MenuEntry.resetMessage) : null,
          shortcut: MenuEntry.resetMessage.shortcut,
          child: Text(MenuEntry.resetMessage.label),
        ),
        SubmenuButton(
          menuChildren: <Widget>[
            MenuItemButton(
              onPressed: () => _activate(MenuEntry.colorRed),
              shortcut: MenuEntry.colorRed.shortcut,
              child: Text(MenuEntry.colorRed.label),
            ),
            MenuItemButton(
              onPressed: () => _activate(MenuEntry.colorGreen),
              shortcut: MenuEntry.colorGreen.shortcut,
              child: Text(MenuEntry.colorGreen.label),
            ),
            MenuItemButton(
              onPressed: () => _activate(MenuEntry.colorBlue),
              shortcut: MenuEntry.colorBlue.shortcut,
              child: Text(MenuEntry.colorBlue.label),
            ),
          ],
          child: const Text('Background Color'),
        ),
      ],
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Dispose of any previously registered shortcuts, since they are about to
    // be replaced.
    _shortcutsEntry?.dispose();
    // Collect the shortcuts from the different menu selections so that they can
    // be registered to apply to the entire app. Menus don't register their
    // shortcuts, they only display the shortcut hint text.
    final Map<ShortcutActivator, Intent> shortcuts = <ShortcutActivator, Intent>{
      for (final MenuEntry item in MenuEntry.values)
        if (item.shortcut != null) item.shortcut!: VoidCallbackIntent(() => _activate(item)),
    };
    // Register the shortcuts with the ShortcutRegistry so that they are
    // available to the entire application.
    _shortcutsEntry = ShortcutRegistry.of(context).addAll(shortcuts);
  }

  @override
  void dispose() {
    _shortcutsEntry?.dispose();
    _menuHandle.dispose();
    _buttonFocusNode.dispose();
    super.dispose();
  }

  bool get showingMessage => _showingMessage;
  bool _showingMessage = false;
  set showingMessage(bool value) {
    if (_showingMessage != value) {
      setState(() {
        _showingMessage = value;
      });
    }
  }

  Color get backgroundColor => _backgroundColor;
  Color _backgroundColor = Colors.red;
  set backgroundColor(Color value) {
    if (_backgroundColor != value) {
      setState(() {
        _backgroundColor = value;
      });
    }
  }

  void _activate(MenuEntry selection) {
    setState(() {
      _lastSelection = selection;
    });
    switch (selection) {
      case MenuEntry.about:
        showAboutDialog(
          context: context,
          applicationName: 'MenuBar Sample',
          applicationVersion: '1.0.0',
        );
        break;
      case MenuEntry.showMessage:
        showingMessage = !showingMessage;
        break;
      case MenuEntry.resetMessage:
      case MenuEntry.hideMessage:
        showingMessage = false;
        break;
      case MenuEntry.colorMenu:
        break;
      case MenuEntry.colorRed:
        backgroundColor = Colors.red;
        break;
      case MenuEntry.colorGreen:
        backgroundColor = Colors.green;
        break;
      case MenuEntry.colorBlue:
        backgroundColor = Colors.blue;
        break;
    }
  }

  void _handleTapDown(TapDownDetails details) {
    if (!HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlLeft) &&
        !HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlRight)) {
      return;
    }
    _menuHandle.open(context, position: details.globalPosition);
  }

  @override
  Widget build(BuildContext context) {
    _updateMenu();
    return GestureDetector(
      onTapDown: _handleTapDown,
      child: Container(
        alignment: Alignment.center,
        color: backgroundColor,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Ctrl-click anywhere on the background to show the menu.'),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                showingMessage ? widget.message : '',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Text(_lastSelection != null ? 'Last Selected: ${_lastSelection!.label}' : ''),
          ],
        ),
      ),
    );
  }
}
