// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';

import '../../gallery/demo.dart';

class CupertinoSwitchDemo extends StatefulWidget {
  static const String routeName = '/cupertino/switch';

  @override
  _CupertinoSwitchDemoState createState() => _CupertinoSwitchDemoState();
}

class _CupertinoSwitchDemoState extends State<CupertinoSwitchDemo> {

  bool _switchValue = false;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Switch'),
        // We're specifying a back label here because the previous page is a
        // Material page. CupertinoPageRoutes could auto-populate these back
        // labels.
        previousPageTitle: 'Cupertino',
        trailing: CupertinoDemoDocumentationButton(CupertinoSwitchDemo.routeName),
      ),
      child: DefaultTextStyle(
        style: CupertinoTheme.of(context).textTheme.textStyle,
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                Semantics(
                  container: true,
                  child: Column(
                    children: <Widget>[
                      CupertinoSwitch(
                        value: _switchValue,
                        onChanged: (bool value) {
                          setState(() {
                            _switchValue = value;
                          });
                        },
                      ),
                      const Text(
                        'Active'
                      ),
                    ],
                  ),
                ),
                Semantics(
                  container: true,
                  child: Column(
                    children: const <Widget>[
                      CupertinoSwitch(
                        value: true,
                        onChanged: null,
                      ),
                      Text(
                        'Enabled'
                      ),
                    ],
                  ),
                ),
                Semantics(
                  container: true,
                  child: Column(
                    children: const <Widget>[
                      CupertinoSwitch(
                        value: false,
                        onChanged: null,
                      ),
                      Text(
                        'Disabled'
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
