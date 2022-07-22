// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';

import 'debug.dart';
import 'desktop_text_selection.dart';
import 'material_localizations.dart';
import 'text_selection_toolbar_text_button.dart';
import 'theme.dart';


/// Calls [builder] with a List of Widgets generated by turning [buttonDatas]
/// into the default buttons for the platform.
///
/// This is useful when building a text selection toolbar with the default
/// button appearance for the given platform, but where the toolbar and/or the
/// button actions and labels may be custom.
///
/// See also:
///
/// * [DefaultTextSelectionToolbar], which builds the toolbar itself. By
///   wrapping [TextSelectionToolbarButtonsBuilder] with
///   [DefaultTextSelectionToolbar] and passing the given children to
///   [DefaultTextSelectionToolbar.children], a default toolbar can be built
///   with custom button actions and labels.
/// * [EditableTextContextMenuButtonDatasBuilder], which is similar to this class,
///   but calls its builder with [ContextMenuButtonData]s instead of with fully
///   built children Widgets.
/// * [CupertinoTextSelectionToolbarButtonsBuilder], which is the Cupertino
///   equivalent of this class and builds only the Cupertino buttons.
class TextSelectionToolbarButtonsBuilder extends StatelessWidget {
  /// Creates an instance of [TextSelectionToolbarButtonsBuilder].
  const TextSelectionToolbarButtonsBuilder({
    super.key,
    required this.buttonDatas,
    required this.builder,
  });

  /// The information used to create each button Widget.
  final List<ContextMenuButtonData> buttonDatas;

  /// Called with a List of Widgets created from the given [buttonDatas].
  ///
  /// Typically builds a text selection toolbar with the given Widgets as
  /// children.
  final ContextMenuFromChildrenBuilder builder;

  static String _getButtonLabel(BuildContext context, ContextMenuButtonData buttonData) {
    if (buttonData.label != null) {
      return buttonData.label!;
    }

    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        assert(debugCheckHasCupertinoLocalizations(context));
        final CupertinoLocalizations localizations = CupertinoLocalizations.of(context);
        switch (buttonData.type) {
          case ContextMenuButtonType.cut:
            return localizations.cutButtonLabel;
          case ContextMenuButtonType.copy:
            return localizations.copyButtonLabel;
          case ContextMenuButtonType.paste:
            return localizations.pasteButtonLabel;
          case ContextMenuButtonType.selectAll:
            return localizations.selectAllButtonLabel;
          case ContextMenuButtonType.custom:
            return '';
        }
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        assert(debugCheckHasMaterialLocalizations(context));
        final MaterialLocalizations localizations = MaterialLocalizations.of(context);
        switch (buttonData.type) {
          case ContextMenuButtonType.cut:
            return localizations.cutButtonLabel;
          case ContextMenuButtonType.copy:
            return localizations.copyButtonLabel;
          case ContextMenuButtonType.paste:
            return localizations.pasteButtonLabel;
          case ContextMenuButtonType.selectAll:
            return localizations.selectAllButtonLabel;
          case ContextMenuButtonType.custom:
            return '';
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    int buttonIndex = 0;
    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
        return builder(
          context,
          buttonDatas.map((ContextMenuButtonData buttonData) {
            return CupertinoTextSelectionToolbarButton.text(
              onPressed: buttonData.onPressed,
              text: _getButtonLabel(context, buttonData),
            );
          }).toList(),
        );
      case TargetPlatform.android:
        return builder(
          context,
          buttonDatas.map((ContextMenuButtonData buttonData) {
            return TextSelectionToolbarTextButton(
              padding: TextSelectionToolbarTextButton.getPadding(buttonIndex++, buttonDatas.length),
              onPressed: buttonData.onPressed,
              child: Text(_getButtonLabel(context, buttonData)),
            );
          }).toList(),
        );
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return builder(
          context,
          buttonDatas.map((ContextMenuButtonData buttonData) {
            return DesktopTextSelectionToolbarButton.text(
              context: context,
              onPressed: buttonData.onPressed,
              text: _getButtonLabel(context, buttonData),
            );
          }).toList(),
        );
      case TargetPlatform.macOS:
        return builder(
          context,
          buttonDatas.map((ContextMenuButtonData buttonData) {
            return CupertinoDesktopTextSelectionToolbarButton.text(
              context: context,
              onPressed: buttonData.onPressed,
              text: _getButtonLabel(context, buttonData),
            );
          }).toList(),
        );
    }
  }
}
