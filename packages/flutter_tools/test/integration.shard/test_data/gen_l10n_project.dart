// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:file/file.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:meta/meta.dart';

import '../test_utils.dart';
import 'project.dart';

class GenL10nProject extends Project {
  @override
  Future<void> setUpIn(Directory dir, {
    bool useDeferredLoading = false,
  }) async {
    await super.setUpIn(dir);
    this.dir = dir;
    writeFile(globals.fs.path.join(dir.path, 'lib', 'l10n', 'app_en.arb'), appEn);
    writeFile(globals.fs.path.join(dir.path, 'lib', 'l10n', 'app_en_CA.arb'), appEnCa);
    writeFile(globals.fs.path.join(dir.path, 'lib', 'l10n', 'app_en_GB.arb'), appEnGb);
    writeFile(globals.fs.path.join(dir.path, 'lib', 'l10n', 'app_es.arb'), appEs);
    writeFile(globals.fs.path.join(dir.path, 'lib', 'l10n', 'app_es_419.arb'), appEs419);
    writeFile(globals.fs.path.join(dir.path, 'lib', 'l10n', 'app_zh.arb'), appZh);
    writeFile(globals.fs.path.join(dir.path, 'lib', 'l10n', 'app_zh_Hant.arb'), appZhHant);
    writeFile(globals.fs.path.join(dir.path, 'lib', 'l10n', 'app_zh_Hans.arb'), appZhHans);
    writeFile(globals.fs.path.join(dir.path, 'lib', 'l10n', 'app_zh_Hant_TW.arb'), appZhHantTw);
    writeFile(globals.fs.path.join(dir.path, 'l10n.yaml'), l10nYaml(useDeferredLoading: useDeferredLoading));
  }

  @override
  final String pubspec = '''
name: test
environment:
  sdk: ">=2.0.0-dev.68.0 <3.0.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  intl: 0.16.1
  intl_translation: 0.17.8
''';

  @override
  final String main = r'''
import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';

class LocaleBuilder extends StatelessWidget {
  const LocaleBuilder({ Key key, this.locale, this.test, this.callback }) : super(key: key);
  final Locale locale;
  final String test;
  final void Function (BuildContext context) callback;
  @override build(BuildContext context) {
    return Localizations.override(
      locale: locale,
      context: context,
      child: ResultBuilder(
        test: test,
        callback: callback,
      ),
    );
  }
}

class ResultBuilder extends StatelessWidget {
  const ResultBuilder({ Key key, this.test, this.callback }) : super(key: key);
  final String test;
  final void Function (BuildContext context) callback;
  @override build(BuildContext context) {
    return Builder(
      builder: (BuildContext context) {
        try {
          callback(context);
        } on Exception catch (e) {
          print('#l10n A(n) $e has occurred trying to generate "$test" results.');
          print('#l10n END');
        }
        return Container();
      },
    );
  }
}

class Home extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final List<String> results = [];
    return Row(
      children: <Widget>[
        LocaleBuilder(
          test: 'supportedLocales',
          callback: (BuildContext context) {
            results.add('--- supportedLocales tests ---');
            int n = 0;
            for (Locale locale in AppLocalizations.supportedLocales) {
              String languageCode = locale.languageCode;
              String countryCode = locale.countryCode;
              String scriptCode = locale.scriptCode;
              results.add('supportedLocales[$n]: languageCode: $languageCode, countryCode: $countryCode, scriptCode: $scriptCode');
              n += 1;
            }
          },
        ),
        LocaleBuilder(
          locale: Locale('en', 'CA'),
          test: 'countryCode - en_CA',
          callback: (BuildContext context) {
            results.add('--- countryCode (en_CA) tests ---');
            results.add(AppLocalizations.of(context).helloWorld);
            results.add(AppLocalizations.of(context).hello("CA fallback World"));
          },
        ),
        LocaleBuilder(
          locale: Locale('en', 'GB'),
          test: 'countryCode - en_GB',
          callback: (BuildContext context) {
            results.add('--- countryCode (en_GB) tests ---');
            results.add(AppLocalizations.of(context).helloWorld);
            results.add(AppLocalizations.of(context).hello("GB fallback World"));
          },
        ),
        LocaleBuilder(
          locale: Locale('zh'),
          test: 'zh',
          callback: (BuildContext context) {
            results.add('--- zh ---');
            results.add(AppLocalizations.of(context).helloWorld);
            results.add(AppLocalizations.of(context).helloWorlds(0));
            results.add(AppLocalizations.of(context).helloWorlds(1));
            results.add(AppLocalizations.of(context).helloWorlds(2));
            // Should use the fallback language, in this case,
            // "Hello 世界" should be displayed.
            results.add(AppLocalizations.of(context).hello("世界"));
          },
        ),
        LocaleBuilder(
          locale: Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
          test: 'zh',
          callback: (BuildContext context) {
            results.add('--- scriptCode: zh_Hans ---');
            results.add(AppLocalizations.of(context).helloWorld);
          },
        ),
        LocaleBuilder(
          locale: Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
          test: 'scriptCode - zh_Hant',
          callback: (BuildContext context) {
            results.add('--- scriptCode - zh_Hant ---');
            results.add(AppLocalizations.of(context).helloWorld);
          },
        ),
        LocaleBuilder(
          locale: Locale.fromSubtags(languageCode: 'zh', countryCode: 'TW', scriptCode: 'Hant'),
          test: 'scriptCode - zh_TW_Hant',
          callback: (BuildContext context) {
            results.add('--- scriptCode - zh_Hant_TW ---');
            results.add(AppLocalizations.of(context).helloWorld);
          },
        ),
        LocaleBuilder(
          locale: Locale('en'),
          test: 'General formatting',
          callback: (BuildContext context) {
            results.add('--- General formatting tests ---');
            final AppLocalizations localizations = AppLocalizations.of(context);
            results.addAll(<String>[
              '${localizations.helloWorld}',
              '${localizations.helloNewlineWorld}',
              '${localizations.hello("World")}',
              '${localizations.greeting("Hello", "World")}',
              '${localizations.helloWorldOn(DateTime(1960))}',
              '${localizations.helloOn("world argument", DateTime(1960), DateTime(1960))}',
              '${localizations.helloWorldDuring(DateTime(1960), DateTime(2020))}',
              '${localizations.helloFor(123)}',
              '${localizations.helloCost("price", 123)}',
              '${localizations.helloWorlds(0)}',
              '${localizations.helloWorlds(1)}',
              '${localizations.helloWorlds(2)}',
              '${localizations.helloAdjectiveWorlds(0, "new")}',
              '${localizations.helloAdjectiveWorlds(1, "new")}',
              '${localizations.helloAdjectiveWorlds(2, "new")}',
              '${localizations.helloWorldsOn(0, DateTime(1960))}',
              '${localizations.helloWorldsOn(1, DateTime(1960))}',
              '${localizations.helloWorldsOn(2, DateTime(1960))}',
              '${localizations.helloWorldPopulation(0, 100)}',
              '${localizations.helloWorldPopulation(1, 101)}',
              '${localizations.helloWorldPopulation(2, 102)}',
              '${localizations.helloWorldsInterpolation(123, "Hello", "World")}',
              '${localizations.dollarSign}',
              '${localizations.dollarSignPlural(1)}',
              '${localizations.singleQuote}',
              '${localizations.singleQuotePlural(2)}',
              '${localizations.doubleQuote}',
              '${localizations.doubleQuotePlural(2)}',
            ]);
          },
        ),
        LocaleBuilder(
          locale: Locale('es'),
          test: '--- es ---',
          callback: (BuildContext context) {
            results.add('--- es ---');
            final AppLocalizations localizations = AppLocalizations.of(context);
            results.addAll(<String>[
              '${localizations.helloWorld}',
              '${localizations.helloNewlineWorld}',
              '${localizations.hello("Mundo")}',
              '${localizations.greeting("Hola", "Mundo")}',
              '${localizations.helloWorldOn(DateTime(1960))}',
              '${localizations.helloOn("world argument", DateTime(1960), DateTime(1960))}',
              '${localizations.helloWorldDuring(DateTime(1960), DateTime(2020))}',
              '${localizations.helloFor(123)}',
              '${localizations.helloCost("el precio", 123)}',
              '${localizations.helloWorlds(0)}',
              '${localizations.helloWorlds(1)}',
              '${localizations.helloWorlds(2)}',
              '${localizations.helloAdjectiveWorlds(0, "nuevo")}',
              '${localizations.helloAdjectiveWorlds(1, "nuevo")}',
              '${localizations.helloAdjectiveWorlds(2, "nuevo")}',
              '${localizations.helloWorldsOn(0, DateTime(1960))}',
              '${localizations.helloWorldsOn(1, DateTime(1960))}',
              '${localizations.helloWorldsOn(2, DateTime(1960))}',
              '${localizations.helloWorldPopulation(0, 100)}',
              '${localizations.helloWorldPopulation(1, 101)}',
              '${localizations.helloWorldPopulation(2, 102)}',
              '${localizations.helloWorldsInterpolation(123, "Hola", "Mundo")}',
              '${localizations.dollarSign}',
              '${localizations.dollarSignPlural(1)}',
              '${localizations.singleQuote}',
              '${localizations.singleQuotePlural(2)}',
              '${localizations.doubleQuote}',
              '${localizations.doubleQuotePlural(2)}',
            ]);
          },
        ),
        LocaleBuilder(
          locale: Locale.fromSubtags(languageCode: 'es', countryCode: '419'),
          test: 'countryCode - es_419',
          callback: (BuildContext context) {
            results.add('--- es_419 ---');
            final AppLocalizations localizations = AppLocalizations.of(context);
            results.addAll([
              '${localizations.helloWorld}',
              '${localizations.helloWorlds(0)}',
              '${localizations.helloWorlds(1)}',
              '${localizations.helloWorlds(2)}',
            ]);
          },
        ),
        LocaleBuilder(
          callback: (BuildContext context) {
            try {
              int n = 0;
              for (final String result in results) {
                // Newline character replacement is necessary because
                // the stream breaks up stdout by new lines.
                print('#l10n $n (${result.replaceAll('\n', '_NEWLINE_')})');
                n += 1;
              }
            }
            finally {
              print('#l10n END');
            }
          },
        ),
      ],
    );
  }
}

void main() {
  runApp(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Home(),
    ),
  );
}
''';

  final String appEn = r'''
{
  "@@locale": "en",

  "helloWorld": "Hello World",
  "@helloWorld": {
    "description": "The conventional newborn programmer greeting"
  },

  "helloNewlineWorld": "Hello \n World",
  "@helloNewlineWorld": {
    "description": "The JSON decoder should convert backslash-n to a newline character in the generated Dart string."
  },

  "hello": "Hello {world}",
  "@hello": {
    "description": "A message with a single parameter",
    "placeholders": {
      "world": {}
    }
  },

  "greeting": "{hello} {world}",
  "@greeting": {
    "description": "A message with a two parameters",
    "placeholders": {
      "hello": {},
      "world": {}
    }
  },

  "helloWorldOn": "Hello World on {date}",
  "@helloWorldOn": {
    "description": "A message with a date parameter",
    "placeholders": {
      "date": {
        "type": "DateTime",
        "format": "yMMMMEEEEd"
      }
    }
  },

  "helloWorldDuring": "Hello World from {startDate} to {endDate}",
  "@helloWorldDuring": {
    "description": "A message with two date parameters",
    "placeholders": {
      "startDate": {
        "type": "DateTime",
        "format": "y"
      },
      "endDate": {
        "type": "DateTime",
        "format": "y"
      }
    }
  },

  "helloOn": "Hello {world} on {date} at {time}",
  "@helloOn": {
    "description": "A message with date and string parameters",
    "placeholders": {
      "world": {
      },
      "date": {
        "type": "DateTime",
        "format": "yMd"
      },
      "time": {
        "type": "DateTime",
        "format": "Hm"
      }
    }
  },

  "helloFor": "Hello for {value}",
  "@helloFor": {
    "description": "A message with a double parameter",
    "placeholders": {
      "value": {
        "type": "double",
        "format": "compact"
      }
    }
  },

  "helloCost": "Hello for {price} {value}",
  "@helloCost": {
    "description": "A message with string and int (currency) parameters",
    "placeholders": {
      "price": {
      },
      "value": {
        "type": "int",
        "format": "currency"
      }
    }
  },

  "helloWorlds": "{count,plural, =0{Hello} =1{Hello World} =2{Hello two worlds} few{Hello {count} worlds} many{Hello all {count} worlds} other{Hello other {count} worlds}}",
  "@helloWorlds": {
    "description": "A plural message",
    "placeholders": {
      "count": {}
    }
  },

  "helloAdjectiveWorlds": "{count,plural, =0{Hello} =1{Hello {adjective} World} =2{Hello two {adjective} worlds} other{Hello other {count} {adjective} worlds}}",
  "@helloAdjectiveWorlds": {
    "description": "A plural message with an additional parameter",
    "placeholders": {
      "count": {},
      "adjective": {}
    }
  },

  "helloWorldsOn": "{count,plural, =0{Hello on {date}} =1{Hello World, on {date}} =2{Hello two worlds, on {date}} other{Hello other {count} worlds, on {date}}}",
  "@helloWorldsOn": {
    "description": "A plural message with an additional date parameter",
    "placeholders": {
      "count": {},
      "date": {
        "type": "DateTime",
        "format": "yMMMMEEEEd"
      }
    }
  },

  "helloWorldPopulation": "{count,plural, =1{Hello World of {population} citizens} =2{Hello two worlds with {population} total citizens} many{Hello all {count} worlds, with a total of {population} citizens} other{Hello other {count} worlds, with a total of {population} citizens}}",
  "@helloWorldPopulation": {
    "description": "A plural message with an additional integer parameter",
    "placeholders": {
      "count": {},
      "population": {
        "type": "int",
        "format": "compactLong"
      }
    }
  },

  "helloWorldInterpolation": "[{hello}] #{world}#",
  "@helloWorldInterpolation": {
    "description": "A message with parameters that need string interpolation braces",
    "placeholders": {
      "hello": {},
      "world": {}
    }
  },

  "helloWorldsInterpolation": "{count,plural, other {[{hello}] -{world}- #{count}#}}",
  "@helloWorldsInterpolation": {
    "description": "A plural message with parameters that need string interpolation braces",
    "placeholders": {
      "count": {},
      "hello": {},
      "world": {}
    }
  },

  "dollarSign": "$!",
  "@dollarSign": {
    "description": "A message with a dollar sign."
  },

  "dollarSignPlural": "{count,plural, =1{One $} other{Many $}}",
  "@dollarSignPlural": {
    "description": "A plural message with a dollar sign.",
    "placeholders": {
      "count": {}
    }
  },

  "singleQuote": "Flutter's amazing!",
  "@singleQuote": {
    "description": "A message with a single quote."
  },

  "singleQuotePlural": "{count,plural, =1{Flutter's amazing, times 1!} other{Flutter's amazing, times {count}!}}",
  "@singleQuotePlural": {
    "description": "A plural message with a single quote.",
    "placeholders": {
      "count": {}
    }
  },

  "doubleQuote": "Flutter is \"amazing\"!",
  "@doubleQuote": {
    "description": "A message with double quotes."
  },

  "doubleQuotePlural": "{count,plural, =1{Flutter is \"amazing\", times 1!} other{Flutter is \"amazing\", times {count}!}}",
  "@doubleQuotePlural": {
    "description": "A plural message with double quotes.",
    "placeholders": {
      "count": {}
    }
  }
}
''';

  final String appEnCa = r'''
{
  "@@locale": "en_CA",
  "helloWorld": "CA Hello World"
}
''';

  final String appEnGb = r'''
{
  "@@locale": "en_GB",
  "helloWorld": "GB Hello World"
}
''';

  /// All messages are simply the template language's message with 'ES - '
  /// appended. This makes validating test behavior easier. The interpolated
  /// messages are different where applicable.
  final String appEs = r'''
{
  "@@locale": "es",
  "helloWorld": "ES - Hello world",
  "helloWorlds": "{count,plural, =0{ES - Hello} =1{ES - Hello World} =2{ES - Hello two worlds} few{ES - Hello {count} worlds} many{ES - Hello all {count} worlds} other{ES - Hello other {count} worlds}}",
  "helloNewlineWorld": "ES - Hello \n World",
  "hello": "ES - Hello {world}",
  "greeting": "ES - {hello} {world}",
  "helloWorldOn": "ES - Hello World on {date}",
  "helloWorldDuring": "ES - Hello World from {startDate} to {endDate}",
  "helloOn": "ES - Hello {world} on {date} at {time}",
  "helloFor": "ES - Hello for {value}",
  "helloCost": "ES - Hello for {price} {value}",
  "helloAdjectiveWorlds": "{count,plural, =0{ES - Hello} =1{ES - Hello {adjective} World} =2{ES - Hello two {adjective} worlds} other{ES - Hello other {count} {adjective} worlds}}",
  "helloWorldsOn": "{count,plural, =0{ES - Hello on {date}} =1{ES - Hello World, on {date}} =2{ES - Hello two worlds, on {date}} other{ES - Hello other {count} worlds, on {date}}}",
  "helloWorldPopulation": "{ES - count,plural, =1{ES - Hello World of {population} citizens} =2{ES - Hello two worlds with {population} total citizens} many{ES - Hello all {count} worlds, with a total of {population} citizens} other{ES - Hello other {count} worlds, with a total of {population} citizens}}",
  "helloWorldInterpolation": "ES - [{hello}] #{world}#",
  "helloWorldsInterpolation": "ES - {count,plural, other {ES - [{hello}] -{world}- #{count}#}}",
  "dollarSign": "ES - $!",
  "dollarSignPlural": "{count,plural, =1{ES - One $} other{ES - Many $}}",
  "singleQuote": "ES - Flutter's amazing!",
  "singleQuotePlural": "{count,plural, =1{ES - Flutter's amazing, times 1!} other{ES - Flutter's amazing, times {count}!}}",
  "doubleQuote": "ES - Flutter is \"amazing\"!",
  "doubleQuotePlural": "{count,plural, =1{ES - Flutter is \"amazing\", times 1!} other{ES - Flutter is \"amazing\", times {count}!}}"
}
''';

  final String appEs419 = r'''
{
  "@@locale": "es_419",
  "helloWorld": "ES 419 - Hello World",
  "helloWorlds": "{count,plural, =0{ES 419 - Hello} =1{ES 419 - Hello World} =2{ES 419 - Hello two worlds} few{ES 419 - Hello {count} worlds} many{ES 419 - Hello all {count} worlds} other{ES - Hello other {count} worlds}}"
}
''';

  final String appZh = r'''
{
  "@@locale": "zh",
  "helloWorld": "你好世界",
  "helloWorlds": "{count,plural, =0{你好} =1{你好世界} other{你好{count}个其他世界}}"
}
''';

  final String appZhHans = r'''
{
  "@@locale": "zh_Hans",
  "helloWorld": "简体你好世界"
}
  ''';

  final String appZhHant = r'''
{
  "@@locale": "zh_Hant",
  "helloWorld": "繁體你好世界"
}
  ''';

  final String appZhHantTw = r'''
{
  "@@locale": "zh_Hant_TW",
  "helloWorld": "台灣繁體你好世界"
}
''';

  String l10nYaml({
    @required bool useDeferredLoading,
  }) {
    if (useDeferredLoading) {
      return r'''
use-deferred-loading: false
      ''';
    }
    return '';
  }
}
