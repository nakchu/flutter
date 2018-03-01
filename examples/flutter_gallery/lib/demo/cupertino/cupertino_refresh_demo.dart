// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:math' show Random;

import 'package:flutter/cupertino.dart';

class CupertinoRefreshControlDemo extends StatefulWidget {
  static const String routeName = '/cupertino/refresh';

  @override
  _CupertinoRefreshControlDemoState createState() => new _CupertinoRefreshControlDemoState();
}

class _CupertinoRefreshControlDemoState extends State<CupertinoRefreshControlDemo> {
  List<List<String>> randomizedContacts;

  @override
  void initState() {
    super.initState();
    repopulateList();
  }

  void repopulateList() {
    final Random random = new Random();
    randomizedContacts = new List<List<String>>.generate(
      100,
      (int index) => contacts[random.nextInt(contacts.length)]
          ..add(random.nextBool().toString()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return new DefaultTextStyle(
      style: const TextStyle(
        fontFamily: '.SF UI Text',
        inherit: false,
        fontSize: 17.0,
        color: CupertinoColors.black,
      ),
      child: new CupertinoPageScaffold(
        child: new DecoratedBox(
          decoration: const BoxDecoration(color: const Color(0xFFEFEFF4)),
          child: new CustomScrollView(
            slivers: <Widget>[
              const CupertinoSliverNavigationBar(
                largeTitle: const Text('Cupertino Refresh Control'),
              ),
              new CupertinoRefreshControl(),
              new SliverSafeArea(
                top: false, // Top safe area is consumed by the navigation bar.
                sliver: new SliverList(
                  delegate: new SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      return new _ListItem(
                        name: randomizedContacts[index][0],
                        place: randomizedContacts[index][1],
                        date: randomizedContacts[index][2],
                        called: randomizedContacts[index][3] == 'true',
                      );
                    },
                    childCount: 100,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<List<String>> contacts = <List<String>>[
  <String>['George Washington', 'Westmoreland County', 'April 30, 1789'],
  <String>['John Adams', 'Braintree', 'March 4, 1797'],
  <String>['Thomas Jefferson', 'Shadwell', 'March 4, 1801'],
  <String>['James Madison', 'Port Conway', 'March 4, 1809'],
  <String>['James Monroe', 'Monroe Hall', 'March 4, 1817'],
  <String>['Andrew Jackson', 'Waxhaws Region South/North', 'March 4, 1829'],
  <String>['John Quincy Adams', 'Braintree', 'March 4, 1825'],
  <String>['William Henry Harrison', 'Charles City County', 'March 4, 1841'],
  <String>['Martin Van Buren', 'Kinderhook New', 'March 4, 1837'],
  <String>['Zachary Taylor', 'Barboursville', 'March 4, 1849'],
  <String>['John Tyler', 'Charles City County', 'April 4, 1841'],
  <String>['James Buchanan', 'Cove Gap', 'March 4, 1857'],
  <String>['James K. Polk', 'Pineville North', 'March 4, 1845'],
  <String>['Millard Fillmore', 'Summerhill New', 'July 9, 1850'],
  <String>['Franklin Pierce', 'Hillsborough New', 'March 4, 1853'],
  <String>['Andrew Johnson', 'Raleigh North', 'April 15, 1865'],
  <String>['Abraham Lincoln', 'Sinking Spring', 'March 4, 1861'],
  <String>['Ulysses S. Grant', 'Point Pleasant', 'March 4, 1869'],
  <String>['Rutherford B. Hayes', 'Delaware', 'March 4, 1877'],
  <String>['Chester A. Arthur', 'Fairfield', 'September 19, 1881'],
  <String>['James A. Garfield', 'Moreland Hills', 'March 4, 1881'],
  <String>['Benjamin Harrison', 'North Bend', 'March 4, 1889'],
  <String>['Grover Cleveland', 'Caldwell New', 'March 4, 1885'],
  <String>['William McKinley', 'Niles', 'March 4, 1897'],
  <String>['Woodrow Wilson', 'Staunton', 'March 4, 1913'],
  <String>['William H. Taft', 'Cincinnati', 'March 4, 1909'],
  <String>['Theodore Roosevelt', 'New York City New', 'September 14, 1901'],
  <String>['Warren G. Harding', 'Blooming Grove', 'March 4, 1921'],
  <String>['Calvin Coolidge', 'Plymouth', 'August 2, 1923'],
  <String>['Herbert Hoover', 'West Branch', 'March 4, 1929'],
  <String>['Franklin D. Roosevelt', 'Hyde Park New', 'March 4, 1933'],
  <String>['Harry S. Truman', 'Lamar', 'April 12, 1945'],
  <String>['Dwight D. Eisenhower', 'Denison', 'January 20, 1953'],
  <String>['Lyndon B. Johnson', 'Stonewall', 'November 22, 1963'],
  <String>['Ronald Reagan', 'Tampico', 'January 20, 1981'],
  <String>['Richard Nixon', 'Yorba Linda', 'January 20, 1969'],
  <String>['Gerald Ford', 'Omaha', 'August 9, 1974'],
  <String>['John F. Kennedy', 'Brookline', 'January 20, 1961'],
  <String>['George H. W. Bush', 'Milton', 'January 20, 1989'],
  <String>['Jimmy Carter', 'Plains', 'January 20, 1977'],
  <String>['George W. Bush', 'New Haven', 'January 20, 2001'],
  <String>['Bill Clinton', 'Hope', 'January 20, 1993'],
  <String>['Barack Obama', 'Honolulu', 'January 20, 2009'],
  <String>['Donald J. Trump', 'New York City', 'January 20, 2017'],
];

class _ListItem extends StatelessWidget {
  const _ListItem({
    this.name,
    this.place,
    this.date,
    this.called,
  });

  final String name;
  final String place;
  final String date;
  final bool called;

  @override
  Widget build(BuildContext context) {
    return new Container(
      decoration: const BoxDecoration(
        color: CupertinoColors.white,
        border: const Border(
          bottom: const BorderSide(color: const Color(0xFFBCBBC1), width: 0.0),
        ),
      ),
      height: 60.0,
      padding: const EdgeInsets.only(top: 9.0, bottom: 9.0, right: 10.0),
      child: new Row(
        children: <Widget>[
          new Container(
            width: 40.0,
            child: called
                ? new Align(
                    alignment: Alignment.topCenter,
                    child: new Icon(
                      CupertinoIcons.phone_solid,
                      color: CupertinoColors.inactiveGray,
                      size: 18.0,
                    ),
                  )
                : null,
          ),
          new Expanded(
            child: new Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                new Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.41,
                  ),
                ),
                new Text(
                  place,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.0,
                    letterSpacing: -0.24,
                    color: CupertinoColors.inactiveGray,
                  ),
                ),
              ],
            ),
          ),
          new Text(
            date,
            style: const TextStyle(
              color: CupertinoColors.inactiveGray,
              fontSize: 15.0,
              letterSpacing: -0.41,
            ),
          ),
          new Padding(
            padding: const EdgeInsets.only(left: 9.0),
            child: new Icon(CupertinoIcons.info, color: CupertinoColors.activeBlue),
          ),
        ],
      ),
    );
  }
}
