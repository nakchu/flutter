// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

import 'gesture_tester.dart';

class TestDrag extends Drag {
  TestDrag({this.onUpdate, this.onEnd, this.onCancel, this.onOutOfBounds});
  final void Function(DragUpdateDetails details)? onUpdate;
  final void Function(DragEndDetails details)? onEnd;
  final void Function()? onCancel;
  final void Function(DragOutOfBoundaryDetails details)? onOutOfBounds;
  @override
  void update(DragUpdateDetails details) {
    onUpdate?.call(details);
  }
  @override
  void end(DragEndDetails details) {
    onEnd?.call(details);
  }
  @override
  void cancel() {
    onCancel?.call();
  }
  @override
  void outOfBounds(DragOutOfBoundaryDetails details) {
    onOutOfBounds?.call(details);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testGesture('MultiDrag: moving before delay rejects', (GestureTester tester) {
    final DelayedMultiDragGestureRecognizer drag = DelayedMultiDragGestureRecognizer();

    bool didStartDrag = false;
    drag.onStart = (Offset position) {
      didStartDrag = true;
      return TestDrag();
    };

    final TestPointer pointer = TestPointer(5);
    final PointerDownEvent down = pointer.down(const Offset(10.0, 10.0));
    drag.addPointer(down);
    tester.closeArena(5);
    expect(didStartDrag, isFalse);
    tester.async.flushMicrotasks();
    expect(didStartDrag, isFalse);
    tester.route(pointer.move(const Offset(20.0, 60.0))); // move more than touch slop before delay expires
    expect(didStartDrag, isFalse);
    tester.async.elapse(kLongPressTimeout * 2); // expire delay
    expect(didStartDrag, isFalse);
    tester.route(pointer.move(const Offset(30.0, 120.0))); // move some more after delay expires
    expect(didStartDrag, isFalse);
    drag.dispose();
  });

  testGesture('MultiDrag: delay triggers', (GestureTester tester) {
    final DelayedMultiDragGestureRecognizer drag = DelayedMultiDragGestureRecognizer();

    bool didStartDrag = false;
    drag.onStart = (Offset position) {
      didStartDrag = true;
      return TestDrag();
    };

    final TestPointer pointer = TestPointer(5);
    final PointerDownEvent down = pointer.down(const Offset(10.0, 10.0));
    drag.addPointer(down);
    tester.closeArena(5);
    expect(didStartDrag, isFalse);
    tester.async.flushMicrotasks();
    expect(didStartDrag, isFalse);
    tester.route(pointer.move(const Offset(20.0, 20.0))); // move less than touch slop before delay expires
    expect(didStartDrag, isFalse);
    tester.async.elapse(kLongPressTimeout * 2); // expire delay
    expect(didStartDrag, isTrue);
    tester.route(pointer.move(const Offset(30.0, 70.0))); // move more than touch slop after delay expires
    expect(didStartDrag, isTrue);
    drag.dispose();
  });

  testGesture('MultiDrag: can filter based on device kind', (GestureTester tester) {
    final DelayedMultiDragGestureRecognizer drag = DelayedMultiDragGestureRecognizer(
      supportedDevices: <PointerDeviceKind>{ PointerDeviceKind.touch },
    );

    bool didStartDrag = false;
    drag.onStart = (Offset position) {
      didStartDrag = true;
      return TestDrag();
    };

    final TestPointer mousePointer = TestPointer(5, PointerDeviceKind.mouse);
    final PointerDownEvent down = mousePointer.down(const Offset(10.0, 10.0));
    drag.addPointer(down);
    tester.closeArena(5);
    expect(didStartDrag, isFalse);
    tester.async.flushMicrotasks();
    expect(didStartDrag, isFalse);
    tester.route(mousePointer.move(const Offset(20.0, 20.0))); // move less than touch slop before delay expires
    expect(didStartDrag, isFalse);
    tester.async.elapse(kLongPressTimeout * 2); // expire delay
    // Still false because it shouldn't recognize mouse events.
    expect(didStartDrag, isFalse);
    tester.route(mousePointer.move(const Offset(30.0, 70.0))); // move more than touch slop after delay expires
    // And still false.
    expect(didStartDrag, isFalse);
    drag.dispose();
  });

  test('allowedButtonsFilter should work the same when null or not specified', () {
    // Regression test for https://github.com/flutter/flutter/pull/122227

    final ImmediateMultiDragGestureRecognizer recognizer1 = ImmediateMultiDragGestureRecognizer();
    // ignore: avoid_redundant_argument_values
    final ImmediateMultiDragGestureRecognizer recognizer2 = ImmediateMultiDragGestureRecognizer(allowedButtonsFilter: null);

    // We want to test _allowedButtonsFilter, which is called in this method.
    const PointerDownEvent allowedPointer = PointerDownEvent(timeStamp: Duration(days: 10));
    // ignore: invalid_use_of_protected_member
    expect(recognizer1.isPointerAllowed(allowedPointer), true);
    // ignore: invalid_use_of_protected_member
    expect(recognizer2.isPointerAllowed(allowedPointer), true);

    const PointerDownEvent rejectedPointer = PointerDownEvent(timeStamp: Duration(days: 10), buttons: kMiddleMouseButton);
    // ignore: invalid_use_of_protected_member
    expect(recognizer1.isPointerAllowed(rejectedPointer), false);
    // ignore: invalid_use_of_protected_member
    expect(recognizer2.isPointerAllowed(rejectedPointer), false);
  });

  test('$MultiDragPointerState dispatches memory events', () async {
    await expectLater(
      await memoryEvents(
        () => _MultiDragPointerState(
          Offset.zero,
          PointerDeviceKind.touch,
          null,
        ).dispose(),
        _MultiDragPointerState,
      ),
      areCreateAndDispose,
    );
  });

  testGesture('The outOfBounds is executed when the drag gesture exceeds the boundary.', (GestureTester tester) {
    final ImmediateMultiDragGestureRecognizer drag = ImmediateMultiDragGestureRecognizer(
      createDragBoundary: (Offset initialPosition) {
        return DragRectBoundary(
          boundary: const Rect.fromLTWH(100, 100, 300, 300),
          rectOffset: const Offset(50, 50),
          rectSize: const Size(100, 100)
        );
      },
      outOfBoundaryBehavior: DragOutOfBoundaryBehavior.callOutOfBoundary,
    );

    final List<String> dragCallbacks = <String>[];
    drag.onStart = (Offset position) {
      return TestDrag(
        onUpdate: (DragUpdateDetails details) {
          dragCallbacks.add('update');
        },
        onEnd: (DragEndDetails details) {
          dragCallbacks.add('end');
        },
        onCancel: () {
          dragCallbacks.add('cancel');
        },
        onOutOfBounds: (DragOutOfBoundaryDetails details) {
          dragCallbacks.add('outOfBounds');
        },
      );
    };

    const PointerDownEvent down = PointerDownEvent(
        pointer: 6,
        position: Offset(200.0, 200.0),
      );
    const PointerMoveEvent move = PointerMoveEvent(
      pointer: 6,
      delta: Offset(200.0, 200.0),
      position: Offset(400.0, 400.0),
    );
    const PointerUpEvent up = PointerUpEvent(
      pointer: 6,
      position: Offset(400.0, 400.0),
    );
    drag.addPointer(down);
    tester.closeArena(down.pointer);
    tester.route(down);
    tester.route(move);
    tester.route(up);
    expect(dragCallbacks, <String>['update', 'outOfBounds', 'update', 'end']);
    drag.dispose();
  });

  testGesture('The drag gesture is cancelled when it exceeds the boundary.', (GestureTester tester) {
    final ImmediateMultiDragGestureRecognizer drag = ImmediateMultiDragGestureRecognizer(
      createDragBoundary: (Offset initialPosition) {
        return DragRectBoundary(
          boundary: const Rect.fromLTWH(100, 100, 300, 300),
          rectOffset: const Offset(50, 50),
          rectSize: const Size(100, 100)
        );
      },
      outOfBoundaryBehavior: DragOutOfBoundaryBehavior.cancel,
    );

    final List<String> dragCallbacks = <String>[];
    drag.onStart = (Offset position) {
      return TestDrag(
        onUpdate: (DragUpdateDetails details) {
          dragCallbacks.add('update');
        },
        onEnd: (DragEndDetails details) {
          dragCallbacks.add('end');
        },
        onCancel: () {
          dragCallbacks.add('cancel');
        },
        onOutOfBounds: (DragOutOfBoundaryDetails details) {
          dragCallbacks.add('outOfBounds');
        },
      );
    };

    const PointerDownEvent down = PointerDownEvent(
        pointer: 6,
        position: Offset(200.0, 200.0),
      );
    const PointerMoveEvent move = PointerMoveEvent(
      pointer: 6,
      delta: Offset(200.0, 200.0),
      position: Offset(400.0, 400.0),
    );
    const PointerUpEvent up = PointerUpEvent(
      pointer: 6,
      position: Offset(400.0, 400.0),
    );
    drag.addPointer(down);
    tester.closeArena(down.pointer);
    tester.route(down);
    tester.route(move);
    tester.route(up);
    expect(dragCallbacks, <String>['update', 'update', 'cancel']);
    drag.dispose();
  });
}

class _MultiDragPointerState extends MultiDragPointerState {
  _MultiDragPointerState(
    super.initialPosition,
    super.kind,
    super.gestureSettings,
  );

  @override
  void accepted(GestureMultiDragStartCallback starter) {}

  @override
  void dispose() {
    super.dispose();
  }
}
