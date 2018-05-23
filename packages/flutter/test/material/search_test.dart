// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Can open and close search', (WidgetTester tester) async {
    final _TestSearchDelegate delegate = new _TestSearchDelegate();
    final List<String> selectedResults = <String>[];

    await tester.pumpWidget(new TestHomePage(
      delegate: delegate,
      results: selectedResults,
    ));

    // We are on the homepage
    expect(find.text('HomeBody'), findsOneWidget);
    expect(find.text('HomeTitle'), findsOneWidget);
    expect(find.text('Suggestions'), findsNothing);

    // Open search
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    expect(find.text('HomeBody'), findsNothing);
    expect(find.text('HomeTitle'), findsNothing);
    expect(find.text('Suggestions'), findsOneWidget);
    expect(selectedResults, hasLength(0));

    final TextField textField = tester.widget(find.byType(TextField));
    expect(textField.focusNode.hasFocus, isTrue);

    // Close search
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('HomeBody'), findsOneWidget);
    expect(find.text('HomeTitle'), findsOneWidget);
    expect(find.text('Suggestions'), findsNothing);
    expect(selectedResults, <String>['Result']);
  });

  testWidgets('Requests suggestions', (WidgetTester tester) async {
    final _TestSearchDelegate delegate = new _TestSearchDelegate();

    await tester.pumpWidget(new TestHomePage(
      delegate: delegate,
    ));
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    expect(delegate.query, '');
    expect(delegate.querysForSuggestions.last, '');
    expect(delegate.querysForResults, hasLength(0));

    // Type W o w into search field
    delegate.querysForSuggestions.clear();
    await tester.enterText(find.byType(TextField), 'W');
    await tester.pumpAndSettle();
    expect(delegate.query, 'W');
    await tester.enterText(find.byType(TextField), 'Wo');
    await tester.pumpAndSettle();
    expect(delegate.query, 'Wo');
    await tester.enterText(find.byType(TextField), 'Wow');
    await tester.pumpAndSettle();
    expect(delegate.query, 'Wow');

    expect(delegate.querysForSuggestions, <String>['W', 'Wo', 'Wow']);
    expect(delegate.querysForResults, hasLength(0));
  });

  testWidgets('Shows Results and closes search', (WidgetTester tester) async {
    final _TestSearchDelegate delegate = new _TestSearchDelegate();
    final List<String> selectedResults = <String>[];

    await tester.pumpWidget(new TestHomePage(
      delegate: delegate,
      results: selectedResults,
    ));
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Wow');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suggestions'));
    await tester.pumpAndSettle();

    // We are on the results page for Wow
    expect(find.text('HomeBody'), findsNothing);
    expect(find.text('HomeTitle'), findsNothing);
    expect(find.text('Suggestions'), findsNothing);
    expect(find.text('Results'), findsOneWidget);

    final TextField textField = tester.widget(find.byType(TextField));
    expect(textField.focusNode.hasFocus, isFalse);
    expect(delegate.querysForResults, <String>['Wow']);

    // Close search
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('HomeBody'), findsOneWidget);
    expect(find.text('HomeTitle'), findsOneWidget);
    expect(find.text('Suggestions'), findsNothing);
    expect(find.text('Results'), findsNothing);
    expect(selectedResults, <String>['Result']);
  });

  testWidgets('Can switch between results and suggestions',
      (WidgetTester tester) async {
    final _TestSearchDelegate delegate = new _TestSearchDelegate();

    await tester.pumpWidget(new TestHomePage(
      delegate: delegate,
    ));
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    // Showing suggestions
    expect(find.text('Suggestions'), findsOneWidget);
    expect(find.text('Results'), findsNothing);

    // Typing query Wow
    delegate.querysForSuggestions.clear();
    await tester.enterText(find.byType(TextField), 'Wow');
    await tester.pumpAndSettle();

    expect(delegate.query, 'Wow');
    expect(delegate.querysForSuggestions, ['Wow']);
    expect(delegate.querysForResults, hasLength(0));

    await tester.tap(find.text('Suggestions'));
    await tester.pumpAndSettle();

    // Showing Results
    expect(find.text('Suggestions'), findsNothing);
    expect(find.text('Results'), findsOneWidget);

    expect(delegate.query, 'Wow');
    expect(delegate.querysForSuggestions, ['Wow']);
    expect(delegate.querysForResults, ['Wow']);

    TextField textField = tester.widget(find.byType(TextField));
    expect(textField.focusNode.hasFocus, isFalse);

    // Taping search field to go back to suggestions
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    textField = tester.widget(find.byType(TextField));
    expect(textField.focusNode.hasFocus, isTrue);

    expect(find.text('Suggestions'), findsOneWidget);
    expect(find.text('Results'), findsNothing);
    expect(delegate.querysForSuggestions, ['Wow', 'Wow']);
    expect(delegate.querysForResults, ['Wow']);

    await tester.enterText(find.byType(TextField), 'Foo');
    await tester.pumpAndSettle();

    expect(delegate.query, 'Foo');
    expect(delegate.querysForSuggestions, ['Wow', 'Wow', 'Foo']);
    expect(delegate.querysForResults, ['Wow']);

    // Go to results again
    await tester.tap(find.text('Suggestions'));
    await tester.pumpAndSettle();

    expect(find.text('Suggestions'), findsNothing);
    expect(find.text('Results'), findsOneWidget);

    expect(delegate.query, 'Foo');
    expect(delegate.querysForSuggestions, ['Wow', 'Wow', 'Foo']);
    expect(delegate.querysForResults, ['Wow', 'Foo']);

    textField = tester.widget(find.byType(TextField));
    expect(textField.focusNode.hasFocus, isFalse);
  });

  testWidgets('Fresh search allways starts with empty query',
      (WidgetTester tester) async {
    final _TestSearchDelegate delegate = new _TestSearchDelegate();

    await tester.pumpWidget(new TestHomePage(
      delegate: delegate,
    ));
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    expect(delegate.query, '');

    delegate.query = 'Foo';
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    expect(delegate.query, '');
  });

  testWidgets('Initial queries are honored', (WidgetTester tester) async {
    final _TestSearchDelegate delegate = new _TestSearchDelegate();

    expect(delegate.query, '');

    await tester.pumpWidget(new TestHomePage(
      delegate: delegate,
      passInInitialQuery: true,
      initialQuery: 'Foo',
    ));
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    expect(delegate.query, 'Foo');
  });

  testWidgets('Initial query null re-used previous query', (WidgetTester tester) async {
    final _TestSearchDelegate delegate = new _TestSearchDelegate();

    delegate.query = 'Foo';

    await tester.pumpWidget(new TestHomePage(
      delegate: delegate,
      passInInitialQuery: true,
      initialQuery: null,
    ));
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    expect(delegate.query, 'Foo');
  });

  testWidgets('Changing query shows up in search field', (WidgetTester tester) async {
    final _TestSearchDelegate delegate = new _TestSearchDelegate();

    await tester.pumpWidget(new TestHomePage(
      delegate: delegate,
      passInInitialQuery: true,
      initialQuery: null,
    ));
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    delegate.query = 'Foo';

    expect(find.text('Foo'), findsOneWidget);
    expect(find.text('Bar'), findsNothing);

    delegate.query = 'Bar';

    expect(find.text('Foo'), findsNothing);
    expect(find.text('Bar'), findsOneWidget);
  });
}

class TestHomePage extends StatelessWidget {
  const TestHomePage(
      {this.results,
      this.delegate,
      this.passInInitialQuery: false,
      this.initialQuery});

  final List<String> results;
  final SearchDelegate<String> delegate;
  final bool passInInitialQuery;
  final String initialQuery;

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      home: Builder(builder: (BuildContext context) {
        return new Scaffold(
          appBar: new AppBar(
            title: const Text('HomeTitle'),
            actions: <Widget>[
              new IconButton(
                tooltip: 'Search',
                icon: const Icon(Icons.search),
                onPressed: () async {
                  String selectedResult;
                  if (passInInitialQuery) {
                    selectedResult = await showSearch<String>(
                      context: context,
                      delegate: delegate,
                      query: initialQuery,
                    );
                  } else {
                    selectedResult = await showSearch<String>(
                      context: context,
                      delegate: delegate,
                    );
                  }
                  results?.add(selectedResult);
                },
              ),
            ],
          ),
          body: const Text('HomeBody'),
        );
      }),
    );
  }
}

class _TestSearchDelegate extends SearchDelegate<String> {
  @override
  Widget buildLeading(BuildContext context) {
    return new IconButton(
      tooltip: 'Back',
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, 'Result');
      },
    );
  }

  final List<String> querysForSuggestions = <String>[];
  final List<String> querysForResults = <String>[];

  @override
  Widget buildSuggestions(BuildContext context) {
    querysForSuggestions.add(query);
    return new MaterialButton(
      onPressed: () {
        showResults(context);
      },
      child: const Text('Suggestions'),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    querysForResults.add(query);
    return const Text('Results');
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return <Widget>[
      new IconButton(
        tooltip: 'Clear',
        icon: const Icon(Icons.clear),
        onPressed: () {},
      )
    ];
  }
}
