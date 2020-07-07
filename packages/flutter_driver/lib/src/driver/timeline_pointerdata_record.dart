// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show json, JsonEncoder;

import 'package:file/file.dart';
import 'package:path/path.dart' as path;

import 'common.dart';
import 'timeline.dart';

const JsonEncoder _prettyEncoder = JsonEncoder.withIndent('  ');

/// Extracts Gestures
class PointerDataRecord {
  /// Filter the recorded timeline events
  PointerDataRecord.filterFrom(Timeline timeline):
    _inputEvents = <Map<String, dynamic>>[
      for(final TimelineEvent event in timeline.events)
        if(event.name == 'GestureBinding receive PointerEvents')
          <String, dynamic> {
            'ts': event.timestampMicros,
            'events': event.arguments['events'],
          },
    ];

  final List<Map<String, dynamic>> _inputEvents;

  /// Write the input events to a json file.
  Future<void> writeToFile(String recordName, {
    String destinationDirectory,
    bool pretty = false,
    bool asDart = false,
  }) async {
    destinationDirectory ??= testOutputsDirectory;
    await fs.directory(destinationDirectory).create(recursive: true);
    final String jsonString = _encodeJson(pretty);
    if (asDart) {
      final File file = fs.file(path.join(destinationDirectory, '$recordName.dart'));
      await file.writeAsString("""
// This file is auto generated by flutter driver for record of pointer events.

const String $recordName = r'''
$jsonString
''';
""");
    }
    else {
      final File file = fs.file(path.join(destinationDirectory, '$recordName.json'));
      await file.writeAsString(jsonString);
    }
  }

  String _encodeJson([bool pretty = false]) {
    return pretty
      ? _prettyEncoder.convert(_inputEvents)
      : json.encode(_inputEvents);
  }
}
