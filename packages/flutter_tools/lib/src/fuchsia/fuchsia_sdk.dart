// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../base/common.dart';
import '../base/context.dart';
import '../base/process.dart';

/// The fuchsia SDK.
FuchsiaSdk get fuchsiaSdk => context[FuchsiaSdk];

/// The fuchsia SDK shell commands.
///
/// This workflow assumes development within the fuchsia source tree, providing
/// the `fx` command-line tool.
class FuchsiaSdk {
  /// Invokes the `netaddr` command and return the output.
  ///
  /// This returns the network address of an attached fuchsia device.
  String netaddr() {
    String text;
    try {
      text = runSync(<String>['fx', 'netaddr', '--fuchsia']);
    } on ArgumentError catch (exception) {
      throwToolExit('Unable to run "netaddr": ${exception.message}');
    }
    return text;
  }

  /// Invokes the `netls` command.
  ///
  /// This lists attached fuchsia devices with their name and address.
  ///
  /// Example output:
  ///     $ fx netls
  ///     > device liliac-shore-only-last (fe80::82e4:da4d:fe81:227d/3)
  String netls() {
    String text;
    try {
      text = runSync(<String>['fx', 'netls']);
    } on ArgumentError catch (exception) {
      throwToolExit('Unable to run "netls": ${exception.message}');
    }
    return text;
  }
}