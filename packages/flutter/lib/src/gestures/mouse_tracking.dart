// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'events.dart';
import 'pointer_router.dart';

/// Signature for listening to [PointerEnterEvent] events.
///
/// Used by [MouseTrackerAnnotation], [Listener] and [RenderPointerListener].
typedef PointerEnterEventListener = void Function(PointerEnterEvent event);

/// Signature for listening to [PointerExitEvent] events.
///
/// Used by [MouseTrackerAnnotation], [Listener] and [RenderPointerListener].
typedef PointerExitEventListener = void Function(PointerExitEvent event);

/// Signature for listening to [PointerHoverEvent] events.
///
/// Used by [MouseTrackerAnnotation], [Listener] and [RenderPointerListener].
typedef PointerHoverEventListener = void Function(PointerHoverEvent event);

/// The annotation object used to annotate layers that are interested in mouse
/// movements.
///
/// This is added to a layer and managed by the [Listener] widget.
class MouseTrackerAnnotation {
  /// Creates an annotation that can be used to find layers interested in mouse
  /// movements.
  const MouseTrackerAnnotation({this.onEnter, this.onHover, this.onExit});

  /// Triggered when a pointer has entered the bounding box of the annotated
  /// layer.
  final PointerEnterEventListener onEnter;

  /// Triggered when a pointer has moved within the bounding box of the
  /// annotated layer.
  final PointerHoverEventListener onHover;

  /// Triggered when a pointer has exited the bounding box of the annotated
  /// layer.
  final PointerExitEventListener onExit;

  @override
  String toString() {
    final List<String> callbacks = <String>[];
    if (onEnter != null)
      callbacks.add('enter');
    if (onHover != null)
      callbacks.add('hover');
    if (onExit != null)
      callbacks.add('exit');
    final String describeCallbacks = callbacks.isEmpty ? '<none>' :
      callbacks.join(' ');
    return '${describeIdentity(this)}(callbacks: $describeCallbacks)';
  }
}

/// Signature for searching for [MouseTrackerAnnotation]s from the given offset.
///
/// It is used by the [MouseTracker] to fetch annotations for the mouse
/// position.
typedef MouseDetectorAnnotationFinder = Iterable<MouseTrackerAnnotation> Function(Offset offset);

class _MouseState {
  _MouseState({
    @required PointerEvent mostRecentEvent ,
  }) : assert(mostRecentEvent != null),
       _mostRecentEvent = mostRecentEvent ;

  // The list of annotations that contains this device during the last frame.
  Set<MouseTrackerAnnotation> lastAnnotations = <MouseTrackerAnnotation>{};

  // The most recent mouse event observed from this device.
  //
  // The [mostRecentEvent] is never null.
  PointerEvent get mostRecentEvent => _mostRecentEvent;
  set mostRecentEvent(PointerEvent value) {
    assert(value != null);
    assert(value.device == _mostRecentEvent.device);
    _mostRecentEvent = value;
  }
  PointerEvent _mostRecentEvent;

  int get device => _mostRecentEvent.device;

  @override
  String toString() {
    final String describeEvent = '${_mostRecentEvent.runtimeType}(device: ${_mostRecentEvent.device})';
    final String describeAnnotations = '[list of ${lastAnnotations.length}]';
    return '${describeIdentity(this)}(event: $describeEvent, annotations: $describeAnnotations)';
  }
}

/// Maintains the relationship between mouse devices and
/// [MouseTrackerAnnotation]s, and notifies interested callbacks of the changes
/// thereof.
///
/// This class is a [ChangeNotifier] that notifies its listeners if the value of
/// [mouseIsConnected] changes.
///
/// This class is a global singleton and owned by the [RendererBinding] class.
class MouseTracker extends ChangeNotifier {
  /// Creates a mouse tracker to keep track of mouse locations.
  ///
  /// The first parameter is a pointer router, which [MouseTracker] will
  /// subscribe to and receive events from. Usually it is global singleton
  /// instance [GestureBinding.pointerRouter].
  ///
  /// The second parameter is a function with which the [MouseTracker] can
  /// search for [MouseTrackerAnnotation]s that contains a given position.
  /// Usually it is [Layer.findAll] of the root layer.
  ///
  /// All of the parameters must not be null.
  MouseTracker(this._router, this.annotationFinder)
      : assert(_router != null),
        assert(annotationFinder != null) {
    _router.addGlobalRoute(_handleEvent);
  }

  @override
  void dispose() {
    super.dispose();
    _router.removeGlobalRoute(_handleEvent);
  }

  /// Find annotations at a given offset in global logical coordinate space.
  ///
  /// [MouseTracker] uses this callback to know which annotations are affected
  /// by each device.
  final MouseDetectorAnnotationFinder annotationFinder;

  // The pointer router that the mouse tracker listens to, and receives new
  // mouse events from.
  final PointerRouter _router;

  // Tracks the state of connected mouse devices.
  //
  // It is a source-of-truth for the list of connected mouse devices.
  //
  // If a device disconnects, the device will be moved to
  // `_disconnectedMouseState`.
  final Map<int, _MouseState> _mouseStates = <int, _MouseState>{};

  // Tracks the state of the disconnected mouse device before its exit callback
  // is called.
  //
  // A device is moved from `_mouseStates` on its disconnecting event, and
  // will be permanantly removed after its exit callback.
  _MouseState _disconnectedMouseState;
  _MouseState _findMouseState(int device) {
    assert(device != null);
    if (device == _disconnectedMouseState?.device)
      return _disconnectedMouseState;
    return _mouseStates[device];
  }

  // Returns the mouse state of a device. If it doesn't exist, create one using
  // `mostRecentEvent`.
  //
  // The returned value is never null.
  _MouseState _guaranteeMouseState(int device, PointerEvent mostRecentEvent) {
    final _MouseState result = _findMouseState(device);
    if (result == null) {
      _addMouseDevice(device, mostRecentEvent);
    }
    return result ?? _mouseStates[device];
  }

  // The collection of annotations that are currently being tracked.
  // It is operated by [attachAnnotation] and [detachAnnotation].
  final Set<MouseTrackerAnnotation> _trackedAnnotations = <MouseTrackerAnnotation>{};
  bool get _hasAttachedAnnotations => _trackedAnnotations.isNotEmpty;

  void _addMouseDevice(int deviceId, PointerEvent event) {
    final bool wasConnected = mouseIsConnected;
    assert(!_mouseStates.containsKey(deviceId));
    assert(_disconnectedMouseState == null);
    _mouseStates[deviceId] = _MouseState(mostRecentEvent: event);
    // Schedule a check to enter annotations that might contain this pointer.
    sendMouseNotifications(<int>{deviceId});
    if (mouseIsConnected != wasConnected) {
      notifyListeners();
    }
  }

  void _removeMouseDevice(int deviceId, PointerEvent event) {
    final bool wasConnected = mouseIsConnected;
    assert(_mouseStates.containsKey(deviceId));
    assert(_disconnectedMouseState == null);
    final _MouseState mouseState = _mouseStates.remove(deviceId);
    _disconnectedMouseState = mouseState;
    mouseState.mostRecentEvent = event;
    // Schedule a check to exit annotations that used to contain this pointer.
    sendMouseNotifications(<int>{deviceId});
    if (mouseIsConnected != wasConnected) {
      notifyListeners();
    }
  }

  // Handler for events coming from the PointerRouter.
  void _handleEvent(PointerEvent event) {
    if (event.kind != PointerDeviceKind.mouse) {
      return;
    }
    final int deviceId = event.device;
    if (event is PointerAddedEvent) {
      _addMouseDevice(deviceId, event);
    } else if (event is PointerRemovedEvent) {
      _removeMouseDevice(deviceId, event);
    } else if (event is PointerHoverEvent) {
      final _MouseState mouseState = _guaranteeMouseState(deviceId, event);
      final PointerEvent previousEvent = mouseState.mostRecentEvent;
      mouseState.mostRecentEvent = event;
      if (previousEvent is PointerAddedEvent || previousEvent.position != event.position) {
        // Only send notifications if we have our first event, or if the
        // location of the mouse has changed, and only if there are tracked annotations.
        sendMouseNotifications(<int>{deviceId});
      }
    }
  }

  bool _scheduledPostFramePositionCheck = false;
  // Schedules a position check at the end of this frame.
  // It is only called during a frame during which annotations have been added.
  void _scheduleMousePositionCheck() {
    // If we're not tracking anything, then there is no point in registering a
    // frame callback or scheduling a frame. By definition there are no active
    // annotations that need exiting, either.
    if (!_scheduledPostFramePositionCheck) {
      _scheduledPostFramePositionCheck = true;
      SchedulerBinding.instance.addPostFrameCallback((Duration duration) {
        sendMouseNotifications(null);
        _scheduledPostFramePositionCheck = false;
      });
    }
  }

  /// Checks if the given [MouseTrackerAnnotation] is attached to this
  /// [MouseTracker].
  ///
  /// This function is only public to allow for proper testing of the
  /// MouseTracker. Do not call in other contexts.
  @visibleForTesting
  bool isAnnotationAttached(MouseTrackerAnnotation annotation) {
    return _trackedAnnotations.contains(annotation);
  }

  /// Collect the latest states of the given mouse devices, and call interested
  /// callbacks.
  ///
  /// Only those devices of [deviceIds] are updated. If [deviceIds] is null,
  /// then all devices are updated. For each of device, the enter or exit events
  /// are called for annotations that the pointer enters or leaves, while hover
  /// events are always called for each annotations that the pointer stays in,
  /// even if the pointer has not moved since the last call. Therefore it's
  /// caller's responsibility to check if the pointer has moved.
  ///
  /// This is called synchronously in most cases, except for when a new
  /// annotation is attached, which is called in a post frame callback.
  ///
  /// This function is only public to allow for proper testing of the
  /// MouseTracker. Do not call in other contexts.
  @visibleForTesting
  void sendMouseNotifications(Iterable<int> deviceIds) {
    if (!_hasAttachedAnnotations) {
      return;
    }

    final Iterable<_MouseState> targetDevices = deviceIds != null ?
      deviceIds.map(_findMouseState) :
      <_MouseState>[
        ..._mouseStates.values,
        if (_disconnectedMouseState != null) _disconnectedMouseState,
      ];

    for (final _MouseState mouseState in targetDevices) {
      final bool isConnected = mouseState != _disconnectedMouseState;
      final PointerEvent mostRecentEvent = mouseState.mostRecentEvent;

      // Order is important for mouse event callbacks. The `findAnnotations`
      // returns annotations in the visual order from front to back. We call
      // it the "visual order", and the opposite one "reverse visual order".
      // The algorithm here is explained in
      // https://github.com/flutter/flutter/issues/41420

      // The annotations that contains this device in the coming frame in
      // visual order.
      final Set<MouseTrackerAnnotation> nextAnnotations = isConnected
        ? annotationFinder(mouseState.mostRecentEvent.position).toSet()
        : const <MouseTrackerAnnotation>{};

      // The annotations that contains this device in the previous frame in
      // visual order.
      final Set<MouseTrackerAnnotation> lastAnnotations = mouseState.lastAnnotations;

      // Send exit events in visual order.
      final Iterable<MouseTrackerAnnotation> exitingAnnotations = lastAnnotations
        .difference(nextAnnotations);
      for (final MouseTrackerAnnotation annotation in exitingAnnotations) {
        if (annotation.onExit != null) {
          annotation.onExit(PointerExitEvent.fromMouseEvent(mostRecentEvent));
        }
      }

      // Send enter events in reverse visual order.
      final Iterable<MouseTrackerAnnotation> enteringAnnotations = nextAnnotations
        .difference(lastAnnotations).toList().reversed;
      for (final MouseTrackerAnnotation annotation in enteringAnnotations) {
        if (annotation.onEnter != null) {
          annotation.onEnter(PointerEnterEvent.fromMouseEvent(mostRecentEvent));
        }
      }

      // Send hover events in reverse visual order.
      // No solid reasons have been brough up on the order between the hover
      // events, except for keeping it aligned with enter events for simplicity.
      if (mostRecentEvent is PointerHoverEvent) {
        final Iterable<MouseTrackerAnnotation> hoveringAnnotations = nextAnnotations
          .toList().reversed;
        for (final MouseTrackerAnnotation annotation in hoveringAnnotations) {
          if (annotation.onHover != null) {
            annotation.onHover(mostRecentEvent);
          }
        }
      }

      mouseState.lastAnnotations = nextAnnotations;
      if (!isConnected)
        _disconnectedMouseState = null;
    }
  }

  /// Whether or not a mouse is connected and has produced events.
  bool get mouseIsConnected => _mouseStates.isNotEmpty;

  /// Notify [MouseTracker] that a new mouse tracker annotation has started to
  /// take effect.
  ///
  /// This should be called as soon as the layer that owns this annotation is
  /// added to the layer tree.
  ///
  /// This triggers [MouseTracker] to schedule a mouse position check during the
  /// post frame to see if this new annotation might trigger enter events.
  ///
  /// The [MouseTracker] also uses this to track the number of attached
  /// annotations, and will skip mouse position checks if there is no
  /// annotations attached.
  void attachAnnotation(MouseTrackerAnnotation annotation) {
    // Schedule a check so that we test this new annotation to see if any mouse
    // is currently inside its region. It has to happen after the frame is
    // complete so that the annotation layer has been added before the check.
    _trackedAnnotations.add(annotation);
    if (mouseIsConnected) {
      _scheduleMousePositionCheck();
    }
  }

  /// Notify [MouseTracker] that a mouse tracker annotation that was previously
  /// attached has stopped taking effect.
  ///
  /// This should be called as soon as the layer that owns this annotation is
  /// removed from the layer tree.
  ///
  /// This triggers [MouseTracker] to perform a mouse position check immediately
  /// to see if this annotation removal triggers any exit events.
  ///
  /// The [MouseTracker] also uses this to track the number of attached
  /// annotations, and will skip mouse position checks if there is no
  /// annotations attached.
  void detachAnnotation(MouseTrackerAnnotation annotation) {
    _mouseStates.forEach((int device, _MouseState mouseState) {
      if (mouseState.lastAnnotations.contains(annotation)) {
        if (annotation.onExit != null) {
          final PointerEvent event = mouseState.mostRecentEvent;
          assert(event != null);
          annotation.onExit(PointerExitEvent.fromMouseEvent(event));
        }
        mouseState.lastAnnotations.remove(annotation);
      }
    });
    _trackedAnnotations.remove(annotation);
  }
}
