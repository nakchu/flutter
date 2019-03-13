// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import 'keyboard_key.dart';
import 'keyboard_maps.dart';
import 'raw_keyboard.dart';

/// Platform-specific key event data for macOS.
///
/// This object contains information about key events obtained from macOS's
/// `NSEvent` interface.
///
/// See also:
///
///  * [RawKeyboard], which uses this interface to expose key data.
class RawKetEventDataMacOs extends RawKeyEventData {
  /// Creates a key event data structure specific for macOS.
  ///
  /// The [characters], [charactersIgnoringModifiers], and [modifiers], arguments
  /// must not be null.
  const RawKetEventDataMacOs(
      {this.characters = '',
      this.charactersIgnoringModifiers = '',
      this.keyCode = 0,
      this.modifiers = 0})
      : assert(characters != null),
        assert(charactersIgnoringModifiers != null),
        assert(keyCode != null),
        assert(modifiers != null);

  /// The Unicode characters associated with a key-up or key-down event.
  ///
  /// See also:
  ///
  ///   * [Apple's NSEvent documentation](https://developer.apple.com/documentation/appkit/nsevent/1534183-characters?language=objc)
  final String characters;

  /// The characters generated by a key event as if no modifier key (except for
  /// Shift) applies.
  ///
  /// See also:
  ///
  ///   * [Apple's NSEvent documentation](https://developer.apple.com/documentation/appkit/nsevent/1524605-charactersignoringmodifiers?language=objc)
  final String charactersIgnoringModifiers;

  /// The virtual key code for the keyboard key associated with a key event.
  ///
  /// See also:
  ///
  ///   * [Apple's NSEvent documentation](https://developer.apple.com/documentation/appkit/nsevent/1534513-keycode?language=objc)
  final int keyCode;

  /// A mask of the current modifiers using the values in Modifier Flags.
  ///
  /// See also:
  ///
  ///   * [Apple's NSEvent documentation](https://developer.apple.com/documentation/appkit/nsevent/1535211-modifierflags?language=objc)
  final int modifiers;

  @override
  String get keyLabel => charactersIgnoringModifiers.isEmpty ? null : charactersIgnoringModifiers;

  @override
  PhysicalKeyboardKey get physicalKey => kMacOsToPhysicalKey[keyCode] ?? PhysicalKeyboardKey.none;

  @override
  LogicalKeyboardKey get logicalKey {
    // Look to see if the keyCode is a printable number pad key, so that a
    // difference between regular keys (e.g. "=") and the number pad version
    // (e.g. the "=" on the number pad) can be determined.
    final LogicalKeyboardKey numPadKey = kMacOsNumPadMap[keyCode];
    if (numPadKey != null) {
      return numPadKey;
    }

    // Look to see if the keyCode is one we know about and have a mapping for.
    if (keyLabel != null &&
        !LogicalKeyboardKey.isControlCharacter(keyLabel) &&
        charactersIgnoringModifiers.isNotEmpty) {
      final int keyId = LogicalKeyboardKey.unicodePlane |
        (charactersIgnoringModifiers.codeUnitAt(0) & LogicalKeyboardKey.valueMask);
      return LogicalKeyboardKey.findKeyByKeyId(keyId) ?? LogicalKeyboardKey(
        keyId,
        keyLabel: keyLabel,
        debugName: kReleaseMode ? null : 'Key ${keyLabel.toUpperCase()}',
      );
    }

    // This is a non-printable key that we don't know about, so we mint a new
    // code with the autogenerated bit set.
    const int macOsKeyIdPlane = 0x00500000000;

    // Keys like "backspace" won't have a character, but it's known by the physical keyboard.
    // Since there is no logical keycode map for macOS (macOS uses the keycode to reference
    // physical keys), a LogicalKeyboardKey is created with the physical key's HID usage and
    // debugName. This avoids the need of duplicating the physical keys map.
    if (physicalKey != PhysicalKeyboardKey.none) {
      return LogicalKeyboardKey(
        physicalKey.usbHidUsage,
        keyLabel: physicalKey.debugName,
        debugName: physicalKey.debugName,
      );
    }

    return LogicalKeyboardKey(
      macOsKeyIdPlane | keyCode | LogicalKeyboardKey.autogeneratedMask,
      debugName: kReleaseMode ? null : 'Unknown macOS key code $keyCode',
    );
  }

  @override
  bool isModifierPressed(ModifierKey key, {KeyboardSide side = KeyboardSide.any}) {
    final int independentModifier = modifiers & deviceIndependentMask;
    switch (key) {
      case ModifierKey.controlModifier:
        return independentModifier & modifierControl != 0;
      case ModifierKey.shiftModifier:
        return independentModifier & modifierShift != 0;
      case ModifierKey.altModifier:
        return independentModifier & modifierOption != 0;
      case ModifierKey.metaModifier:
        return independentModifier & modifierCommand != 0;
      case ModifierKey.capsLockModifier:
        return independentModifier & modifierCapsLock != 0;
      case ModifierKey.numLockModifier:
        return independentModifier & modifierNumericPad != 0;
      case ModifierKey.functionModifier:
      case ModifierKey.symbolModifier:
      case ModifierKey.scrollLockModifier:
        // These are not included in macOS.
        return false;
    }
    return false;
  }

  @override
  KeyboardSide getModifierSide(ModifierKey key) => KeyboardSide.any;

  // Modifier key masks. Apple's NSEvent documentation
  // https://developer.apple.com/documentation/appkit/nseventmodifierflags?language=objc

  /// This mask is used to check the [modifiers] field to test whether the CAPS
  /// LOCK modifier key is on.
  ///
  /// Use this value if you need to decode the [modifiers] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierCapsLock = 1 << 16;

  /// This mask is used to check the [modifiers] field to test whether one of the
  /// SHIFT modifier keys is pressed.
  ///
  /// Use this value if you need to decode the [modifiers] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierShift = 1 << 17;

  /// This mask is used to check the [modifiers] field to test whether one of the
  /// CTRL modifier keys is pressed.
  ///
  /// Use this value if you need to decode the [modifiers] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierControl = 1 << 18;

  /// This mask is used to check the [modifiers] field to test whether one of the
  /// ALT modifier keys is pressed.
  ///
  /// Use this value if you need to decode the [modifiers] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierOption = 1 << 19;

  /// This mask is used to check the [modifiers] field to test whether one of the
  /// CMD modifier keys is pressed.
  ///
  /// Use this value if you need to decode the [modifiers] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierCommand = 1 << 20;

  /// This mask is used to check the [modifiers] field to test whether any key in
  /// the numeric keypad is pressed.
  ///
  /// Use this value if you need to decode the [modifiers] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierNumericPad = 1 << 21;

  /// This mask is used to check the [modifiers] field to test whether the
  /// HELP modifier key is pressed.
  ///
  /// Use this value if you need to decode the [modifiers] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierHelp = 1 << 22;

  /// This mask is used to check the [modifiers] field to test whether one of the
  /// FUNCTION modifier keys is pressed.
  ///
  /// Use this value if you need to decode the [modifiers] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierFunction = 1 << 23;

  /// Used to retrieve only the device-independent modifier flags, allowing
  /// applications to mask off the device-dependent modifier flags, including
  /// event coalescing information.
  static const int deviceIndependentMask = 0xffff0000;

  @override
  String toString() {
    return '$runtimeType(keyLabel: $keyLabel, keyCode: $keyCode, characters: $characters,'
        ' unmodifiedCharacters: $charactersIgnoringModifiers, modifiers: $modifiers, '
        'modifiers down: $modifiersPressed)';
  }
}
