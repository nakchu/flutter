// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'theme.dart';

/// Applies a chip theme to descendant [RawChip]-based widgets, like [Chip],
/// [InputChip], [ChoiceChip], [FilterChip], and [ActionChip].
///
/// A chip theme describes the color, shape and text styles for the chips it is
/// applied to.
///
/// Descendant widgets obtain the current theme's [ChipThemeData] object using
/// [ChipTheme.of]. When a widget uses [ChipTheme.of], it is automatically
/// rebuilt if the theme later changes.
///
/// The [ThemeData] object given by the [Theme.of] call also contains a default
/// [ThemeData.chipTheme] that can be customized by copying it (using
/// [ChipThemeData.copyWith]).
///
/// See also:
///
///  * [Chip], a chip that displays information and can be deleted.
///  * [InputChip], a chip that represents a complex piece of information, such
///    as an entity (person, place, or thing) or conversational text, in a
///    compact form.
///  * [ChoiceChip], allows a single selection from a set of options. Choice
///    chips contain related descriptive text or categories.
///  * [FilterChip], uses tags or descriptive words as a way to filter content.
///  * [ActionChip], represents an action related to primary content.
///  * [ChipThemeData], which describes the actual configuration of a chip
///    theme.
///  * [ThemeData], which describes the overall theme information for the
///    application.
class ChipTheme extends InheritedTheme {
  /// Applies the given theme [data] to [child].
  ///
  /// The [data] and [child] arguments must not be null.
  const ChipTheme({
    Key? key,
    required this.data,
    required Widget child,
  }) : assert(child != null),
       assert(data != null),
       super(key: key, child: child);

  /// Specifies the color, shape, and text style values for descendant chip
  /// widgets.
  final ChipThemeData data;

  /// Returns the data from the closest [ChipTheme] instance that encloses
  /// the given context.
  ///
  /// Defaults to the ambient [ThemeData.chipTheme] if there is no
  /// [ChipTheme] in the given build context.
  ///
  /// {@tool snippet}
  ///
  /// ```dart
  /// class Spaceship extends StatelessWidget {
  ///   const Spaceship({Key? key}) : super(key: key);
  ///
  ///   @override
  ///   Widget build(BuildContext context) {
  ///     return ChipTheme(
  ///       data: ChipTheme.of(context).copyWith(backgroundColor: Colors.red),
  ///       child: ActionChip(
  ///         label: const Text('Launch'),
  ///         onPressed: () { print('We have liftoff!'); },
  ///       ),
  ///     );
  ///   }
  /// }
  /// ```
  /// {@end-tool}
  ///
  /// See also:
  ///
  ///  * [ChipThemeData], which describes the actual configuration of a chip
  ///    theme.
  static ChipThemeData of(BuildContext context) {
    final ChipTheme? inheritedTheme = context.dependOnInheritedWidgetOfExactType<ChipTheme>();
    return inheritedTheme?.data ?? Theme.of(context).chipTheme;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return ChipTheme(data: data, child: child);
  }

  @override
  bool updateShouldNotify(ChipTheme oldWidget) => data != oldWidget.data;
}

/// Holds the color, shape, and text styles for a material design chip theme.
///
/// Use this class to configure a [ChipTheme] widget, or to set the
/// [ThemeData.chipTheme] for a [Theme] widget.
///
/// To obtain the current ambient chip theme, use [ChipTheme.of].
///
/// The parts of a chip are:
///
///  * The "avatar", which is a widget that appears at the beginning of the
///    chip. This is typically a [CircleAvatar] widget.
///  * The "label", which is the widget displayed in the center of the chip.
///    Typically this is a [Text] widget.
///  * The "delete icon", which is a widget that appears at the end of the chip.
///  * The chip is disabled when it is not accepting user input. Only some chips
///    have a disabled state: [InputChip], [ChoiceChip], and [FilterChip].
///
/// The simplest way to create a ChipThemeData is to use [copyWith] on the one
/// you get from [ChipTheme.of], or create an entirely new one with
/// [ChipThemeData.fromDefaults].
///
/// {@tool snippet}
///
/// ```dart
/// class CarColor extends StatefulWidget {
///   const CarColor({Key? key}) : super(key: key);
///
///   @override
///   State createState() => _CarColorState();
/// }
///
/// class _CarColorState extends State<CarColor> {
///   Color _color = Colors.red;
///
///   @override
///   Widget build(BuildContext context) {
///     return ChipTheme(
///       data: ChipTheme.of(context).copyWith(backgroundColor: Colors.lightBlue),
///       child: ChoiceChip(
///         label: const Text('Light Blue'),
///         onSelected: (bool value) {
///           setState(() {
///             _color = value ? Colors.lightBlue : Colors.red;
///           });
///         },
///         selected: _color == Colors.lightBlue,
///       ),
///     );
///   }
/// }
/// ```
/// {@end-tool}
///
/// See also:
///
///  * [Chip], a chip that displays information and can be deleted.
///  * [InputChip], a chip that represents a complex piece of information, such
///    as an entity (person, place, or thing) or conversational text, in a
///    compact form.
///  * [ChoiceChip], allows a single selection from a set of options. Choice
///    chips contain related descriptive text or categories.
///  * [FilterChip], uses tags or descriptive words as a way to filter content.
///  * [ActionChip], represents an action related to primary content.
///  * [CircleAvatar], which shows images or initials of entities.
///  * [Wrap], A widget that displays its children in multiple horizontal or
///    vertical runs.
///  * [ChipTheme] widget, which can override the chip theme of its
///    children.
///  * [Theme] widget, which performs a similar function to [ChipTheme],
///    but for overall themes.
///  * [ThemeData], which has a default [ChipThemeData].
@immutable
class ChipThemeData with Diagnosticable {
  /// Create a [ChipThemeData] given a set of exact values. All the values
  /// must be specified except for [shadowColor], [selectedShadowColor],
  /// [elevation], and [pressElevation], which may be null.
  ///
  /// This will rarely be used directly. It is used by [lerp] to
  /// create intermediate themes based on two themes.
  const ChipThemeData({
    required this.backgroundColor,
    this.deleteIconColor,
    required this.disabledColor,
    required this.selectedColor,
    required this.secondarySelectedColor,
    this.shadowColor,
    this.selectedShadowColor,
    this.showCheckmark,
    this.checkmarkColor,
    this.labelPadding,
    required this.padding,
    this.side,
    this.shape,
    required this.labelStyle,
    required this.secondaryLabelStyle,
    required this.brightness,
    this.elevation,
    this.pressElevation,
  }) : assert(backgroundColor != null),
       assert(disabledColor != null),
       assert(selectedColor != null),
       assert(secondarySelectedColor != null),
       assert(padding != null),
       assert(labelStyle != null),
       assert(secondaryLabelStyle != null),
       assert(brightness != null);

  /// Generates a ChipThemeData from a brightness, a primary color, and a text
  /// style.
  ///
  /// The [brightness] is used to select a primary color from the default
  /// values.
  ///
  /// The optional [primaryColor] is used as the base color for the other
  /// colors. The opacity of the [primaryColor] is ignored. If a [primaryColor]
  /// is specified, then the [brightness] is ignored, and the theme brightness
  /// is determined from the [primaryColor].
  ///
  /// Only one of [primaryColor] or [brightness] may be specified.
  ///
  /// The [secondaryColor] is used for the selection colors needed by
  /// [ChoiceChip].
  ///
  /// This is used to generate the default chip theme for a [ThemeData].
  factory ChipThemeData.fromDefaults({
    Brightness? brightness,
    Color? primaryColor,
    required Color secondaryColor,
    required TextStyle labelStyle,
  }) {
    assert(primaryColor != null || brightness != null, 'One of primaryColor or brightness must be specified');
    assert(primaryColor == null || brightness == null, 'Only one of primaryColor or brightness may be specified');
    assert(secondaryColor != null);
    assert(labelStyle != null);

    if (primaryColor != null) {
      brightness = ThemeData.estimateBrightnessForColor(primaryColor);
    }

    // These are Material Design defaults, and are used to derive
    // component Colors (with opacity) from base colors.
    const int backgroundAlpha = 0x1f; // 12%
    const int deleteIconAlpha = 0xde; // 87%
    const int disabledAlpha = 0x0c; // 38% * 12% = 5%
    const int selectAlpha = 0x3d; // 12% + 12% = 24%
    const int textLabelAlpha = 0xde; // 87%
    const EdgeInsetsGeometry padding = EdgeInsets.all(4.0);

    primaryColor = primaryColor ?? (brightness == Brightness.light ? Colors.black : Colors.white);
    final Color backgroundColor = primaryColor.withAlpha(backgroundAlpha);
    final Color deleteIconColor = primaryColor.withAlpha(deleteIconAlpha);
    final Color disabledColor = primaryColor.withAlpha(disabledAlpha);
    final Color selectedColor = primaryColor.withAlpha(selectAlpha);
    final Color secondarySelectedColor = secondaryColor.withAlpha(selectAlpha);
    final TextStyle secondaryLabelStyle = labelStyle.copyWith(
      color: secondaryColor.withAlpha(textLabelAlpha),
    );
    labelStyle = labelStyle.copyWith(color: primaryColor.withAlpha(textLabelAlpha));

    return ChipThemeData(
      backgroundColor: backgroundColor,
      deleteIconColor: deleteIconColor,
      disabledColor: disabledColor,
      selectedColor: selectedColor,
      secondarySelectedColor: secondarySelectedColor,
      padding: padding,
      labelStyle: labelStyle,
      secondaryLabelStyle: secondaryLabelStyle,
      brightness: brightness!,
    );
  }

  /// Color to be used for the unselected, enabled chip's background.
  ///
  /// The default is light grey.
  final Color backgroundColor;

  /// The [Color] for the delete icon. The default is Color(0xde000000)
  /// (slightly transparent black) for light themes, and Color(0xdeffffff)
  /// (slightly transparent white) for dark themes.
  ///
  /// May be set to null, in which case the ambient [IconThemeData.color] is used.
  final Color? deleteIconColor;

  /// Color to be used for the chip's background indicating that it is disabled.
  ///
  /// The chip is disabled when [DisabledChipAttributes.isEnabled] is false, or
  /// all three of [SelectableChipAttributes.onSelected],
  /// [TappableChipAttributes.onPressed], and
  /// [DeletableChipAttributes.onDeleted] are null.
  ///
  /// It defaults to [Colors.black38].
  final Color disabledColor;

  /// Color to be used for the chip's background, indicating that it is
  /// selected.
  ///
  /// The chip is selected when [SelectableChipAttributes.selected] is true.
  final Color selectedColor;

  /// An alternate color to be used for the chip's background, indicating that
  /// it is selected. For example, this color is used by [ChoiceChip] when the
  /// choice is selected.
  ///
  /// The chip is selected when [SelectableChipAttributes.selected] is true.
  final Color secondarySelectedColor;

  /// Color of the chip's shadow when the elevation is greater than 0.
  ///
  /// If null, the chip defaults to [Colors.black].
  ///
  /// See also:
  ///
  ///  * [selectedShadowColor]
  final Color? shadowColor;

  /// Color of the chip's shadow when the elevation is greater than 0 and the
  /// chip is selected.
  ///
  /// If null, the chip defaults to [Colors.black].
  ///
  /// See also:
  ///
  ///  * [shadowColor]
  final Color? selectedShadowColor;

  /// Whether or not to show a check mark when [SelectableChipAttributes.selected] is true.
  ///
  /// For instance, the [ChoiceChip] sets this to false so that it can be
  /// selected without showing the check mark.
  ///
  /// Defaults to true.
  final bool? showCheckmark;

  /// Color of the chip's check mark when a check mark is visible.
  ///
  /// This will override the color set by the platform's brightness setting.
  final Color? checkmarkColor;

  /// The padding around the [Chip.label] widget.
  ///
  /// By default, this is 4 logical pixels at the beginning and the end of the
  /// label, and zero on top and bottom.
  final EdgeInsetsGeometry? labelPadding;

  /// The padding between the contents of the chip and the outside [shape].
  ///
  /// Defaults to 4 logical pixels on all sides.
  final EdgeInsetsGeometry padding;

  /// The color and weight of the chip's outline.
  ///
  /// If null, the chip defaults to the border side of [shape].
  ///
  /// This value is combined with [shape] to create a shape decorated with an
  /// outline. If it is a [MaterialStateBorderSide],
  /// [MaterialStateProperty.resolve] is used for the following
  /// [MaterialState]s:
  ///
  ///  * [MaterialState.disabled].
  ///  * [MaterialState.selected].
  ///  * [MaterialState.hovered].
  ///  * [MaterialState.focused].
  ///  * [MaterialState.pressed].
  final BorderSide? side;

  /// The border to draw around the chip.
  ///
  /// If null, the chip defaults to a [StadiumBorder].
  ///
  /// This shape is combined with [side] to create a shape decorated with an
  /// outline. If it is a [MaterialStateOutlinedBorder],
  /// [MaterialStateProperty.resolve] is used for the following
  /// [MaterialState]s:
  ///
  ///  * [MaterialState.disabled].
  ///  * [MaterialState.selected].
  ///  * [MaterialState.hovered].
  ///  * [MaterialState.focused].
  ///  * [MaterialState.pressed].
  final OutlinedBorder? shape;

  /// The style to be applied to the chip's label.
  ///
  /// This only has an effect on label widgets that respect the
  /// [DefaultTextStyle], such as [Text].
  final TextStyle labelStyle;

  /// An alternate style to be applied to the chip's label. For example, this
  /// style is applied to the text of a selected [ChoiceChip].
  ///
  /// This only has an effect on label widgets that respect the
  /// [DefaultTextStyle], such as [Text].
  final TextStyle secondaryLabelStyle;

  /// The brightness setting for this theme.
  ///
  /// This affects various base material color choices in the chip rendering.
  final Brightness brightness;

  /// The elevation to be applied to the chip.
  ///
  /// If null, the chip defaults to 0.
  final double? elevation;

  /// The elevation to be applied to the chip during the press motion.
  ///
  /// If null, the chip defaults to 8.
  final double? pressElevation;

  /// Creates a copy of this object but with the given fields replaced with the
  /// new values.
  ChipThemeData copyWith({
    Color? backgroundColor,
    Color? deleteIconColor,
    Color? disabledColor,
    Color? selectedColor,
    Color? secondarySelectedColor,
    Color? shadowColor,
    Color? selectedShadowColor,
    Color? checkmarkColor,
    EdgeInsetsGeometry? labelPadding,
    EdgeInsetsGeometry? padding,
    BorderSide? side,
    OutlinedBorder? shape,
    TextStyle? labelStyle,
    TextStyle? secondaryLabelStyle,
    Brightness? brightness,
    double? elevation,
    double? pressElevation,
  }) {
    return ChipThemeData(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      deleteIconColor: deleteIconColor ?? this.deleteIconColor,
      disabledColor: disabledColor ?? this.disabledColor,
      selectedColor: selectedColor ?? this.selectedColor,
      secondarySelectedColor: secondarySelectedColor ?? this.secondarySelectedColor,
      shadowColor: shadowColor ?? this.shadowColor,
      selectedShadowColor: selectedShadowColor ?? this.selectedShadowColor,
      checkmarkColor: checkmarkColor ?? this.checkmarkColor,
      labelPadding: labelPadding ?? this.labelPadding,
      padding: padding ?? this.padding,
      side: side ?? this.side,
      shape: shape ?? this.shape,
      labelStyle: labelStyle ?? this.labelStyle,
      secondaryLabelStyle: secondaryLabelStyle ?? this.secondaryLabelStyle,
      brightness: brightness ?? this.brightness,
      elevation: elevation ?? this.elevation,
      pressElevation: pressElevation ?? this.pressElevation,
    );
  }

  /// Linearly interpolate between two chip themes.
  ///
  /// The arguments must not be null.
  ///
  /// {@macro dart.ui.shadow.lerp}
  static ChipThemeData? lerp(ChipThemeData? a, ChipThemeData? b, double t) {
    if (a == null && b == null)
      return null;
    return ChipThemeData(
      backgroundColor: Color.lerp(a?.backgroundColor, b?.backgroundColor, t)!,
      deleteIconColor: Color.lerp(a?.deleteIconColor, b?.deleteIconColor, t),
      disabledColor: Color.lerp(a?.disabledColor, b?.disabledColor, t)!,
      selectedColor: Color.lerp(a?.selectedColor, b?.selectedColor, t)!,
      secondarySelectedColor: Color.lerp(a?.secondarySelectedColor, b?.secondarySelectedColor, t)!,
      shadowColor: Color.lerp(a?.shadowColor, b?.shadowColor, t),
      selectedShadowColor: Color.lerp(a?.selectedShadowColor, b?.selectedShadowColor, t),
      checkmarkColor: Color.lerp(a?.checkmarkColor, b?.checkmarkColor, t),
      labelPadding: EdgeInsetsGeometry.lerp(a?.labelPadding, b?.labelPadding, t),
      padding: EdgeInsetsGeometry.lerp(a?.padding, b?.padding, t)!,
      side: _lerpSides(a?.side, b?.side, t),
      shape: _lerpShapes(a?.shape, b?.shape, t),
      labelStyle: TextStyle.lerp(a?.labelStyle, b?.labelStyle, t)!,
      secondaryLabelStyle: TextStyle.lerp(a?.secondaryLabelStyle, b?.secondaryLabelStyle, t)!,
      brightness: t < 0.5 ? a?.brightness ?? Brightness.light : b?.brightness ?? Brightness.light,
      elevation: lerpDouble(a?.elevation, b?.elevation, t),
      pressElevation: lerpDouble(a?.pressElevation, b?.pressElevation, t),
    );
  }

  // Special case because BorderSide.lerp() doesn't support null arguments.
  static BorderSide? _lerpSides(BorderSide? a, BorderSide? b, double t) {
    if (a == null && b == null)
      return null;
    if (a == null)
      return BorderSide.lerp(BorderSide(width: 0, color: b!.color.withAlpha(0)), b, t);
    if (b == null)
      return BorderSide.lerp(BorderSide(width: 0, color: a.color.withAlpha(0)), a, t);
    return BorderSide.lerp(a, b, t);
  }

  // TODO(perclasson): OutlinedBorder needs a lerp method - https://github.com/flutter/flutter/issues/60555.
  static OutlinedBorder? _lerpShapes(OutlinedBorder? a, OutlinedBorder? b, double t) {
    if (a == null && b == null)
      return null;
    return ShapeBorder.lerp(a, b, t) as OutlinedBorder?;
  }

  @override
  int get hashCode {
    return hashValues(
      backgroundColor,
      deleteIconColor,
      disabledColor,
      selectedColor,
      secondarySelectedColor,
      shadowColor,
      selectedShadowColor,
      checkmarkColor,
      labelPadding,
      padding,
      side,
      shape,
      labelStyle,
      secondaryLabelStyle,
      brightness,
      elevation,
      pressElevation,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ChipThemeData
        && other.backgroundColor == backgroundColor
        && other.deleteIconColor == deleteIconColor
        && other.disabledColor == disabledColor
        && other.selectedColor == selectedColor
        && other.secondarySelectedColor == secondarySelectedColor
        && other.shadowColor == shadowColor
        && other.selectedShadowColor == selectedShadowColor
        && other.checkmarkColor == checkmarkColor
        && other.labelPadding == labelPadding
        && other.padding == padding
        && other.side == side
        && other.shape == shape
        && other.labelStyle == labelStyle
        && other.secondaryLabelStyle == secondaryLabelStyle
        && other.brightness == brightness
        && other.elevation == elevation
        && other.pressElevation == pressElevation;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    final ThemeData defaultTheme = ThemeData.fallback();
    final ChipThemeData defaultData = ChipThemeData.fromDefaults(
      secondaryColor: defaultTheme.primaryColor,
      brightness: defaultTheme.brightness,
      labelStyle: defaultTheme.textTheme.bodyText1!,
    );
    properties.add(ColorProperty('backgroundColor', backgroundColor, defaultValue: defaultData.backgroundColor));
    properties.add(ColorProperty('deleteIconColor', deleteIconColor, defaultValue: defaultData.deleteIconColor));
    properties.add(ColorProperty('disabledColor', disabledColor, defaultValue: defaultData.disabledColor));
    properties.add(ColorProperty('selectedColor', selectedColor, defaultValue: defaultData.selectedColor));
    properties.add(ColorProperty('secondarySelectedColor', secondarySelectedColor, defaultValue: defaultData.secondarySelectedColor));
    properties.add(ColorProperty('shadowColor', shadowColor, defaultValue: defaultData.shadowColor));
    properties.add(ColorProperty('selectedShadowColor', selectedShadowColor, defaultValue: defaultData.selectedShadowColor));
    properties.add(ColorProperty('checkMarkColor', checkmarkColor, defaultValue: defaultData.checkmarkColor));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('labelPadding', labelPadding, defaultValue: defaultData.labelPadding));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('padding', padding, defaultValue: defaultData.padding));
    properties.add(DiagnosticsProperty<BorderSide>('side', side, defaultValue: defaultData.side));
    properties.add(DiagnosticsProperty<ShapeBorder>('shape', shape, defaultValue: defaultData.shape));
    properties.add(DiagnosticsProperty<TextStyle>('labelStyle', labelStyle, defaultValue: defaultData.labelStyle));
    properties.add(DiagnosticsProperty<TextStyle>('secondaryLabelStyle', secondaryLabelStyle, defaultValue: defaultData.secondaryLabelStyle));
    properties.add(EnumProperty<Brightness>('brightness', brightness, defaultValue: defaultData.brightness));
    properties.add(DoubleProperty('elevation', elevation, defaultValue: defaultData.elevation));
    properties.add(DoubleProperty('pressElevation', pressElevation, defaultValue: defaultData.pressElevation));
  }
}
