// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../build_info.dart';
import '../runner/flutter_command.dart' show ExitStatus, FlutterCommandResult;
import '../web/compile.dart';
import 'build.dart';

class BuildWebCommand extends BuildSubCommand {
  BuildWebCommand() {
    usesTargetOption();
    usesPubOption();
    defaultBuildMode = BuildMode.release;
  }

  @override
  final String name = 'web';
  
  @override
  bool get hidden => true;

  @override
  final String description = 'Build an Web application bundle.';

  @override
  Future<FlutterCommandResult> runCommand() async {
    final String target = argResults['target'];
    await webCompiler.compile(target: target);
    return const FlutterCommandResult(ExitStatus.success);
  }
}
