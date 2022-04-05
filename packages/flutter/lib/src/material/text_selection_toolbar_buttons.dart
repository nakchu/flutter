import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'debug.dart';
import 'desktop_text_selection.dart';
import 'material_localizations.dart';
import 'text_selection_toolbar_text_button.dart';
import 'theme.dart';

/// Calls [builder] with a list of Widgets generated by turning [buttonDatas]
/// into the default buttons for the platform.
///
/// See also:
///
/// * [TextSelectionToolbarButtonDatasBuilder], which builds the
///   [ContextualMenuButtonData]s.
/// * [DefaultTextSelectionToolbar], which builds the toolbar itself.
class TextSelectionToolbarButtonsBuilder extends StatelessWidget {
  /// Creates an instance of [TextSelectionToolbarButtonsBuilder].
  const TextSelectionToolbarButtonsBuilder({
    Key? key,
    required this.buttonDatas,
    required this.builder,
  }) : super(key: key);

  /// The information used to create each button Widget.
  final List<ContextualMenuButtonData> buttonDatas;

  /// Called with a List of Widgets created from the given [buttonDatas].
  ///
  /// Typically builds a text selection toolbar with the given Widgets as
  /// children.
  final ContextualMenuFromChildrenBuilder builder;

  // TODO(justinmc): Dedupe?
  static String _getMaterialButtonLabel(DefaultContextualMenuButtonType type, MaterialLocalizations localizations) {
    switch (type) {
      case DefaultContextualMenuButtonType.cut:
        return localizations.cutButtonLabel;
      case DefaultContextualMenuButtonType.copy:
        return localizations.copyButtonLabel;
      case DefaultContextualMenuButtonType.paste:
        return localizations.pasteButtonLabel;
      case DefaultContextualMenuButtonType.selectAll:
        return localizations.selectAllButtonLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    int buttonIndex = 0;
    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
        assert(debugCheckHasCupertinoLocalizations(context));
        final CupertinoLocalizations localizations = CupertinoLocalizations.of(context);
        return builder(
          context,
          buttonDatas.map((ContextualMenuButtonData buttonData) {
            return CupertinoTextSelectionToolbarButton.text(
              onPressed: buttonData.onPressed,
              text: CupertinoTextSelectionToolbarButton.getButtonLabel(buttonData.type, localizations),
            );
          }).toList(),
        );
      case TargetPlatform.android:
        assert(debugCheckHasMaterialLocalizations(context));
        final MaterialLocalizations localizations = MaterialLocalizations.of(context);
        return builder(
          context,
          buttonDatas.map((ContextualMenuButtonData buttonData) {
            return TextSelectionToolbarTextButton(
              padding: TextSelectionToolbarTextButton.getPadding(buttonIndex++, buttonDatas.length),
              onPressed: buttonData.onPressed,
              child: Text(_getMaterialButtonLabel(buttonData.type, localizations)),
            );
          }).toList(),
        );
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        assert(debugCheckHasMaterialLocalizations(context));
        final MaterialLocalizations localizations = MaterialLocalizations.of(context);
        return builder(
          context,
          buttonDatas.map((ContextualMenuButtonData buttonData) {
            return DesktopTextSelectionToolbarButton.text(
              context: context,
              onPressed: buttonData.onPressed,
              text: _getMaterialButtonLabel(buttonData.type, localizations),
            );
          }).toList(),
        );
      case TargetPlatform.macOS:
        assert(debugCheckHasCupertinoLocalizations(context));
        final CupertinoLocalizations localizations = CupertinoLocalizations.of(context);
        return builder(
          context,
          buttonDatas.map((ContextualMenuButtonData buttonData) {
            return CupertinoDesktopTextSelectionToolbarButton.text(
              context: context,
              onPressed: buttonData.onPressed,
              text: CupertinoTextSelectionToolbarButton.getButtonLabel(buttonData.type, localizations),
            );
          }).toList(),
        );
    }
  }
}
