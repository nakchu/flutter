// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:async';

import 'package:file/file.dart';

import '../src/common.dart';
import 'test_data/gen_l10n_project.dart';
import 'test_driver.dart';
import 'test_utils.dart';

final GenL10nProject project = GenL10nProject();

// Verify that the code generated by gen_l10n executes correctly.
// It can fail if gen_l10n produces a lib/l10n/app_localizations.dart that
// does not analyze cleanly.
void main() {
  Directory tempDir;
  FlutterRunTestDriver flutter;

  setUp(() async {
    tempDir = createResolvedTempDirectorySync('gen_l10n_test.');
  });

  tearDown(() async {
    await flutter.stop();
    tryToDelete(tempDir);
  });

  Future<StringBuffer> runApp() async {
    // Run the app defined in GenL10nProject.main and wait for it to
    // send '#l10n END' to its stdout.
    final Completer<void> l10nEnd = Completer<void>();
    final StringBuffer stdout = StringBuffer();
    final StreamSubscription<String> subscription = flutter.stdout.listen((String line) {
      if (line.contains('#l10n')) {
        stdout.writeln(line.substring(line.indexOf('#l10n')));
      }
      if (line.contains('#l10n END')) {
        l10nEnd.complete();
      }
    });
    await flutter.run();
    await l10nEnd.future;
    await subscription.cancel();
    return stdout;
  }

  void expectOutput(StringBuffer stdout) {
    expect(stdout.toString(),
      '#l10n 0 (--- supportedLocales tests ---)\n'
      '#l10n 1 (supportedLocales[0]: languageCode: en, countryCode: null, scriptCode: null)\n'
      '#l10n 2 (supportedLocales[1]: languageCode: en, countryCode: CA, scriptCode: null)\n'
      '#l10n 3 (supportedLocales[2]: languageCode: en, countryCode: GB, scriptCode: null)\n'
      '#l10n 4 (supportedLocales[3]: languageCode: es, countryCode: null, scriptCode: null)\n'
      '#l10n 5 (supportedLocales[4]: languageCode: es, countryCode: 419, scriptCode: null)\n'
      '#l10n 6 (supportedLocales[5]: languageCode: zh, countryCode: null, scriptCode: null)\n'
      '#l10n 7 (supportedLocales[6]: languageCode: zh, countryCode: null, scriptCode: Hans)\n'
      '#l10n 8 (supportedLocales[7]: languageCode: zh, countryCode: null, scriptCode: Hant)\n'
      '#l10n 9 (supportedLocales[8]: languageCode: zh, countryCode: TW, scriptCode: Hant)\n'
      '#l10n 10 (--- countryCode (en_CA) tests ---)\n'
      '#l10n 11 (CA Hello World)\n'
      '#l10n 12 (Hello CA fallback World)\n'
      '#l10n 13 (--- countryCode (en_GB) tests ---)\n'
      '#l10n 14 (GB Hello World)\n'
      '#l10n 15 (Hello GB fallback World)\n'
      '#l10n 16 (--- zh ---)\n'
      '#l10n 17 (你好世界)\n'
      '#l10n 18 (你好)\n'
      '#l10n 19 (你好世界)\n'
      '#l10n 20 (你好2个其他世界)\n'
      '#l10n 21 (Hello 世界)\n'
      '#l10n 22 (zh - Hello for 价钱 CNY123.00)\n'
      '#l10n 23 (--- scriptCode: zh_Hans ---)\n'
      '#l10n 24 (简体你好世界)\n'
      '#l10n 25 (--- scriptCode - zh_Hant ---)\n'
      '#l10n 26 (繁體你好世界)\n'
      '#l10n 27 (--- scriptCode - zh_Hant_TW ---)\n'
      '#l10n 28 (台灣繁體你好世界)\n'
      '#l10n 29 (--- General formatting tests ---)\n'
      '#l10n 30 (Hello World)\n'
      '#l10n 31 (Hello _NEWLINE_ World)\n'
      '#l10n 32 (Hello \$ World)\n'
      '#l10n 33 (Hello World)\n'
      '#l10n 34 (Hello World)\n'
      '#l10n 35 (Hello World on Friday, January 1, 1960)\n'
      '#l10n 36 (Hello world argument on 1/1/1960 at 00:00)\n'
      '#l10n 37 (Hello World from 1960 to 2020)\n'
      '#l10n 38 (Hello for 123)\n'
      '#l10n 39 (Hello for price USD123.00)\n'
      '#l10n 40 (Hello for price BTC0.50 (with optional param))\n'
      "#l10n 41 (Hello for price BTC'0.50 (with special character))\n"
      '#l10n 42 (Hello for price BTC"0.50 (with special character))\n'
      '#l10n 43 (Hello for price BTC"\'0.50 (with special character))\n'
      '#l10n 44 (Hello for Decimal Pattern 1,200,000)\n'
      '#l10n 45 (Hello for Percent Pattern 120,000,000%)\n'
      '#l10n 46 (Hello for Scientific Pattern 1E6)\n'
      '#l10n 47 (Hello)\n'
      '#l10n 48 (Hello World)\n'
      '#l10n 49 (Hello two worlds)\n'
      '#l10n 50 (Hello)\n'
      '#l10n 51 (Hello new World)\n'
      '#l10n 52 (Hello two new worlds)\n'
      '#l10n 53 (Hello on Friday, January 1, 1960)\n'
      '#l10n 54 (Hello World, on Friday, January 1, 1960)\n'
      '#l10n 55 (Hello two worlds, on Friday, January 1, 1960)\n'
      '#l10n 56 (Hello other 0 worlds, with a total of 100 citizens)\n'
      '#l10n 57 (Hello World of 101 citizens)\n'
      '#l10n 58 (Hello two worlds with 102 total citizens)\n'
      '#l10n 59 ([Hello] -World- #123#)\n'
      '#l10n 60 (\$!)\n'
      '#l10n 61 (One \$)\n'
      "#l10n 62 (Flutter's amazing!)\n"
      "#l10n 63 (Flutter's amazing, times 2!)\n"
      '#l10n 64 (Flutter is "amazing"!)\n'
      '#l10n 65 (Flutter is "amazing", times 2!)\n'
      '#l10n 66 (16 wheel truck)\n'
      "#l10n 67 (Sedan's elegance)\n"
      '#l10n 68 (Cabriolet has "acceleration")\n'
      '#l10n 69 (Oh, she found 1 item!)\n'
      '#l10n 70 (Indeed, they like Flutter!)\n'
      '#l10n 71 (--- es ---)\n'
      '#l10n 72 (ES - Hello world)\n'
      '#l10n 73 (ES - Hello _NEWLINE_ World)\n'
      '#l10n 74 (ES - Hola \$ Mundo)\n'
      '#l10n 75 (ES - Hello Mundo)\n'
      '#l10n 76 (ES - Hola Mundo)\n'
      '#l10n 77 (ES - Hello World on viernes, 1 de enero de 1960)\n'
      '#l10n 78 (ES - Hello world argument on 1/1/1960 at 0:00)\n'
      '#l10n 79 (ES - Hello World from 1960 to 2020)\n'
      '#l10n 80 (ES - Hello for 123)\n'
      '#l10n 81 (ES - Hello)\n'
      '#l10n 82 (ES - Hello World)\n'
      '#l10n 83 (ES - Hello two worlds)\n'
      '#l10n 84 (ES - Hello)\n'
      '#l10n 85 (ES - Hello nuevo World)\n'
      '#l10n 86 (ES - Hello two nuevo worlds)\n'
      '#l10n 87 (ES - Hello on viernes, 1 de enero de 1960)\n'
      '#l10n 88 (ES - Hello World, on viernes, 1 de enero de 1960)\n'
      '#l10n 89 (ES - Hello two worlds, on viernes, 1 de enero de 1960)\n'
      '#l10n 90 (ES - Hello other 0 worlds, with a total of 100 citizens)\n'
      '#l10n 91 (ES - Hello World of 101 citizens)\n'
      '#l10n 92 (ES - Hello two worlds with 102 total citizens)\n'
      '#l10n 93 (ES - [Hola] -Mundo- #123#)\n'
      '#l10n 94 (ES - \$!)\n'
      '#l10n 95 (ES - One \$)\n'
      "#l10n 96 (ES - Flutter's amazing!)\n"
      "#l10n 97 (ES - Flutter's amazing, times 2!)\n"
      '#l10n 98 (ES - Flutter is "amazing"!)\n'
      '#l10n 99 (ES - Flutter is "amazing", times 2!)\n'
      '#l10n 100 (ES - 16 wheel truck)\n'
      "#l10n 101 (ES - Sedan's elegance)\n"
      '#l10n 102 (ES - Cabriolet has "acceleration")\n'
      '#l10n 103 (ES - Oh, she found ES - 1 itemES - !)\n'
      '#l10n 104 (ES - Indeed, ES - they like ES - Flutter!)\n'
      '#l10n 105 (--- es_419 ---)\n'
      '#l10n 106 (ES 419 - Hello World)\n'
      '#l10n 107 (ES 419 - Hello)\n'
      '#l10n 108 (ES 419 - Hello World)\n'
      '#l10n 109 (ES 419 - Hello two worlds)\n'
      '#l10n END\n'
    );
  }

  // TODO(jsimmons): need a localization test that uses deferred loading
  // (see https://github.com/flutter/flutter/issues/61911)
  testWithoutContext('generated l10n classes produce expected localized strings', () async {
    await project.setUpIn(tempDir);
    flutter = FlutterRunTestDriver(tempDir);
    final StringBuffer stdout = await runApp();
    expectOutput(stdout);
  });
}
