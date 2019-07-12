// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/build_system/exceptions.dart';

import '../src/common.dart';

void main() {
  test('Exceptions', () {
    final MissingInputException missingInputException = MissingInputException(
        <File>[fs.file('foo'), fs.file('bar')], 'example');
    final CycleException cycleException = CycleException(const <Target>{
      Target(
        name: 'foo',
        buildAction: null,
        inputs: <Source>[],
        outputs: <Source>[],
      ),
      Target(
        name: 'bar',
        buildAction: null,
        inputs: <Source>[],
        outputs: <Source>[],
      )
    });
    final InvalidPatternException invalidPatternException = InvalidPatternException(
      'ABC'
    );
    final MissingOutputException missingOutputException = MissingOutputException(
      <File>[ fs.file('foo'), fs.file('bar') ],
      'example'
    );
    final MisplacedOutputException misplacedOutputException = MisplacedOutputException(
      'foo',
      'example',
    );
    final MissingDefineException missingDefineException = MissingDefineException(
      'foobar',
      'example',
    );

    expect(
        missingInputException.toString(),
        'foo, bar were declared as an inputs, '
        'but did not exist. Check the definition of target:example for errors');
    expect(
        cycleException.toString(),
        'Dependency cycle detected in build: foo -> bar'
    );
    expect(
        invalidPatternException.toString(),
        'The pattern "ABC" is not valid'
    );
    expect(
        missingOutputException.toString(),
        'foo, bar were declared as outputs, but were not generated by the '
        'action. Check the definition of target:example for errors'
    );
    expect(
        misplacedOutputException.toString(),
        'Target example produced an output at foo which is outside of the '
        'current build or project directory',
    );
    expect(
        missingDefineException.toString(),
        'Target example required define foobar but it was not provided'
    );
  });
}
