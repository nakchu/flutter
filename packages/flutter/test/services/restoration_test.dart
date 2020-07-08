// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'restoration.dart';

void main() {
  group('RestorationId', () {
    test('has good toString', () {
      expect(const RestorationId('hello').toString(), 'RestorationId(hello)');
      expect(const RestorationId('world').toString(), 'RestorationId(world)');
    });

    test('equal values are equal', () {
      expect(const RestorationId('hello') == const RestorationId('world'), isFalse);
      expect(const RestorationId('hello') == const RestorationId('hello'), isTrue);
      int i = 0;
      expect(RestorationId('hello ${i++}') == const RestorationId('hello 0'), isTrue);
      expect(RestorationId('hello ${i++}') == RestorationId('hello ${--i}'), isTrue);
      expect(RestorationId('hello ${i++}') == RestorationId('hello $i'), isFalse);
    });
  });

  group('RestorationManager', () {
    testWidgets('root bucket retrieval', (WidgetTester tester) async {
      final List<MethodCall> callsToEngine = <MethodCall>[];
      final Completer<Uint8List> result = Completer<Uint8List>();
      SystemChannels.restoration.setMockMethodCallHandler((MethodCall call) {
        callsToEngine.add(call);
        return result.future;
      });

      final RestorationManager manager = RestorationManager();
      final Future<RestorationBucket> rootBucketFuture = manager.rootBucket;
      RestorationBucket rootBucket;
      rootBucketFuture.then((RestorationBucket bucket) {
        rootBucket = bucket;
      });
      expect(rootBucketFuture, isNotNull);
      expect(rootBucket, isNull);

      // Accessing rootBucket again gives same future.
      expect(manager.rootBucket, same(rootBucketFuture));

      // Engine has only been contacted once.
      expect(callsToEngine, hasLength(1));
      expect(callsToEngine.single.method, 'get');

      // Complete the engine request.
      result.complete(_createEncodedRestorationData1());
      await tester.pump();

      // Root bucket future completed.
      expect(rootBucket, isNotNull);

      // Root bucket contains the expected data.
      expect(rootBucket.get<int>(const RestorationId('value1')), 10);
      expect(rootBucket.get<String>(const RestorationId('value2')), 'Hello');
      final RestorationBucket child = rootBucket.claimChild(const RestorationId('child1'), debugOwner: null);
      expect(child.get<int>(const RestorationId('another value')), 22);

      // Accessing the root bucket again completes synchronously with same bucket.
      RestorationBucket synchronousBucket;
      manager.rootBucket.then((RestorationBucket bucket) {
        synchronousBucket = bucket;
      });
      expect(synchronousBucket, isNotNull);
      expect(synchronousBucket, same(rootBucket));
    });

    testWidgets('root bucket received from engine before retrival', (WidgetTester tester) async {
      SystemChannels.restoration.setMethodCallHandler(null);
      final List<MethodCall> callsToEngine = <MethodCall>[];
      SystemChannels.restoration.setMockMethodCallHandler((MethodCall call) {
        callsToEngine.add(call);
        return null;
      });
      final RestorationManager manager = RestorationManager();

      await _pushDataFromEngine(_createEncodedRestorationData1());

      RestorationBucket rootBucket;
      manager.rootBucket.then((RestorationBucket bucket) => rootBucket = bucket);
      // Root bucket is available synchronously.
      expect(rootBucket, isNotNull);
      // Engine was never asked.
      expect(callsToEngine, isEmpty);
    });

    testWidgets('root bucket is properly replaced when new data is available', (WidgetTester tester) async {
      SystemChannels.restoration.setMockMethodCallHandler((MethodCall call) async {
        return _createEncodedRestorationData1();
      });
      final RestorationManager manager = RestorationManager();
      RestorationBucket rootBucket;
      manager.rootBucket.then((RestorationBucket bucket) {
        rootBucket = bucket;
      });
      await tester.pump();
      expect(rootBucket, isNotNull);
      expect(rootBucket.get<int>(const RestorationId('value1')), 10);
      final RestorationBucket child = rootBucket.claimChild(const RestorationId('child1'), debugOwner: null);
      expect(child.get<int>(const RestorationId('another value')), 22);

      bool rootDecommissioned = false;
      bool childDecommissioned = false;
      RestorationBucket newRoot;
      rootBucket.addListener(() {
        rootDecommissioned = true;
        manager.rootBucket.then((RestorationBucket bucket) {
          newRoot = bucket;
        });
        // The new bucket is available synchronously.
        expect(newRoot, isNotNull);
      });
      child.addListener(() {
        childDecommissioned = true;
      });

      // Send new Data.
      await _pushDataFromEngine(_createEncodedRestorationData2());

      expect(rootDecommissioned, isTrue);
      expect(childDecommissioned, isTrue);
      expect(newRoot, isNot(same(rootBucket)));

      child.dispose();

      expect(newRoot.get<int>(const RestorationId('foo')), 33);
      expect(newRoot.get<int>(const RestorationId('value1')), null);
      final RestorationBucket newChild = newRoot.claimChild(const RestorationId('childFoo'), debugOwner: null);
      expect(newChild.get<String>(const RestorationId('bar')), 'Hello');
    });

    testWidgets('scheduleUpdate runs finalizers and sends data to engine', (WidgetTester tester) async {
      final List<MethodCall> callsToEngine = <MethodCall>[];
      SystemChannels.restoration.setMockMethodCallHandler((MethodCall call) async {
        callsToEngine.add(call);
        return call.method == 'get' ? _createEncodedRestorationData1() : null;
      });
      final RestorationManager manager = RestorationManager();
      RestorationBucket rootBucket;
      manager.rootBucket.then((RestorationBucket bucket) {
        rootBucket = bucket;
      });
      await tester.pump();
      expect(rootBucket, isNotNull);
      callsToEngine.clear();

      int finalizerRunCount = 0;
      manager.scheduleSerialization(finalizer: () {
        finalizerRunCount++;
      });
      tester.binding.scheduleFrame(); // Serialization happens post-frame.
      expect(finalizerRunCount, 0);
      expect(callsToEngine, isEmpty);

      await tester.pump();

      expect(finalizerRunCount, 1);
      expect(callsToEngine, hasLength(1));
      expect(callsToEngine.single.method, 'put');

      final Uint8List dataSendToEngine = callsToEngine.single.arguments as Uint8List;
      final Map<String, dynamic> decodedData = castToMap<String, dynamic>(
        const StandardMessageCodec().decodeMessage(dataSendToEngine.buffer.asByteData(dataSendToEngine.offsetInBytes, dataSendToEngine.lengthInBytes)),
      );
      expect(decodedData[valuesMapKey]['value1'], 10);
      expect(decodedData[valuesMapKey]['value2'], 'Hello');

      // Old finalizer is not invoked again.
      manager.scheduleSerialization();
      tester.binding.scheduleFrame();
      await tester.pump();
      expect(finalizerRunCount, 1);
      expect(callsToEngine, hasLength(2));
      expect(callsToEngine.every((MethodCall m) => m.method == 'put'), isTrue);
    });

    testWidgets('each finalizer is only called once', (WidgetTester tester) async {
      final List<MethodCall> callsToEngine = <MethodCall>[];
      SystemChannels.restoration.setMockMethodCallHandler((MethodCall call) async {
        callsToEngine.add(call);
        return call.method == 'get' ? _createEncodedRestorationData1() : null;
      });
      final RestorationManager manager = RestorationManager();
      RestorationBucket rootBucket;
      manager.rootBucket.then((RestorationBucket bucket) {
        rootBucket = bucket;
      });
      await tester.pump();
      expect(rootBucket, isNotNull);
      callsToEngine.clear();

      int finalizerFooCount = 0;
      void finalizerFoo() {
        finalizerFooCount++;
      }
      int finalizerBarCount = 0;
      void finalizerBar() {
        finalizerBarCount++;
      }

      manager.scheduleSerialization(finalizer: finalizerFoo);
      manager.scheduleSerialization(finalizer: finalizerBar);
      manager.scheduleSerialization(finalizer: finalizerFoo);
      manager.scheduleSerialization();
      manager.scheduleSerialization(finalizer: finalizerFoo);
      tester.binding.scheduleFrame(); // Serialization happens post-frame.

      expect(finalizerFooCount, 0);
      expect(finalizerBarCount, 0);
      expect(callsToEngine, hasLength(0));

      await tester.pump();

      expect(finalizerFooCount, 1);
      expect(finalizerBarCount, 1);
      expect(callsToEngine, hasLength(1));
      expect(callsToEngine.single.method, 'put');
    });

    testWidgets('cannot call scheduleUpdate from finalizer', (WidgetTester tester) async {
      final List<MethodCall> callsToEngine = <MethodCall>[];
      SystemChannels.restoration.setMockMethodCallHandler((MethodCall call) async {
        callsToEngine.add(call);
        return null;
      });
      final RestorationManager manager = RestorationManager();
      RestorationBucket rootBucket;
      manager.rootBucket.then((RestorationBucket bucket) {
        rootBucket = bucket;
      });
      await tester.pump();
      expect(rootBucket, isNotNull);

      final List<AssertionError> errors = <AssertionError>[];
      manager.scheduleSerialization(finalizer: () {
        try {
          manager.scheduleSerialization();
        } on AssertionError catch (e) {
          errors.add(e);
        }
      });

      tester.binding.scheduleFrame();
      await tester.pump();

      expect(errors, hasLength(1));
      expect(errors.single.message, 'Calling scheduleUpdate from a finalizer is not allowed.');
    });
  });

  test('debugIsSerializableForRestoration', () {
    expect(debugIsSerializableForRestoration(Object()), isFalse);
    expect(debugIsSerializableForRestoration(Container()), isFalse);

    expect(debugIsSerializableForRestoration(null), isTrue);
    expect(debugIsSerializableForRestoration(147823), isTrue);
    expect(debugIsSerializableForRestoration(12.43), isTrue);
    expect(debugIsSerializableForRestoration('Hello World'), isTrue);
    expect(debugIsSerializableForRestoration(<int>[12, 13, 14]), isTrue);
    expect(debugIsSerializableForRestoration(<String, int>{'v1' : 10, 'v2' : 23}), isTrue);
    expect(debugIsSerializableForRestoration(<String, dynamic>{
      'hello': <int>[12, 12, 12],
      'world': <int, bool>{
        1: true,
        2: false,
        4: true,
      },
    }), isTrue);
  });
}

Future<void> _pushDataFromEngine(Uint8List data) async {
  await ServicesBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/restoration',
    const StandardMethodCodec().encodeMethodCall(MethodCall('push', data)),
    (_) { },
  );
}

Uint8List _createEncodedRestorationData1() {
  final Map<String, dynamic> data = <String, dynamic>{
    valuesMapKey: <String, dynamic>{
      'value1' : 10,
      'value2' : 'Hello',
    },
    childrenMapKey: <String, dynamic>{
      'child1' : <String, dynamic>{
        valuesMapKey : <String, dynamic>{
          'another value': 22,
        }
      },
    },
  };
  final ByteData encoded = const StandardMessageCodec().encodeMessage(data);
  return encoded.buffer.asUint8List(encoded.offsetInBytes, encoded.lengthInBytes);
}

Uint8List _createEncodedRestorationData2() {
  final Map<String, dynamic> data = <String, dynamic>{
    valuesMapKey: <String, dynamic>{
      'foo' : 33,
    },
    childrenMapKey: <String, dynamic>{
      'childFoo' : <String, dynamic>{
        valuesMapKey : <String, dynamic>{
          'bar': 'Hello',
        }
      },
    },
  };
  final ByteData encoded = const StandardMessageCodec().encodeMessage(data);
  return encoded.buffer.asUint8List(encoded.offsetInBytes, encoded.lengthInBytes);
}
