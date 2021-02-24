// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart' as vm_service;

import 'base/logger.dart';
import 'resident_runner.dart';
import 'vmservice.dart';

typedef ResidentDevtoolsHandlerFactory = ResidentDevtoolsHandler Function(DevtoolsLauncher, ResidentRunner, Logger);

ResidentDevtoolsHandler createDefaultHandler(DevtoolsLauncher launcher, ResidentRunner runner, Logger logger) {
  return FlutterResidentDevtoolsHandler(launcher, runner, logger);
}

/// Helper class to manage the life-cycle of devtools and its interaction with
/// the resident runner.
abstract class ResidentDevtoolsHandler {
  /// The current devtools server, or null if one is not running.
  DevToolsServerAddress get activeDevToolsServer;

  Future<void> hotRestart(List<FlutterDevice> flutterDevices);

  Future<void> serveAndAnnounceDevTools({Uri devToolsServerAddress, List<FlutterDevice> flutterDevices});

  Future<void> shutdown();
}

class FlutterResidentDevtoolsHandler implements ResidentDevtoolsHandler {
  FlutterResidentDevtoolsHandler(this._devToolsLauncher, this._residentRunner, this._logger);

  final DevtoolsLauncher _devToolsLauncher;
  final ResidentRunner _residentRunner;
  final Logger _logger;
  bool _shutdown = false;
  bool _served = false;

  @override
  DevToolsServerAddress get activeDevToolsServer =>  _devToolsLauncher?.activeDevToolsServer;

  // This must be guaranteed not to return a Future that fails.
  @override
  Future<void> serveAndAnnounceDevTools({
    Uri devToolsServerAddress,
    @required List<FlutterDevice> flutterDevices,
  }) async {
    if (!_residentRunner.supportsServiceProtocol || _devToolsLauncher == null) {
      return;
    }
    if (devToolsServerAddress != null) {
      _devToolsLauncher.devToolsUrl = devToolsServerAddress;
    } else {
      _served = true;
      await _devToolsLauncher.serve();
    }
    await _devToolsLauncher.ready;

    if (_residentRunner.reportedDebuggers) {
      // Since the DevTools only just became available, we haven't had a chance to
      // report their URLs yet. Do so now.
      _residentRunner.printDebuggerList(includeObservatory: false);
    }
    await _waitForExtensions(flutterDevices);
    await _maybeCallDevToolsUriServiceExtension(
      flutterDevices,
    );
    await _callConnectedVmServiceUriExtension(
      flutterDevices,
    );
  }

   Future<void> _maybeCallDevToolsUriServiceExtension(
     List<FlutterDevice> flutterDevices,
   ) async {
     if (_devToolsLauncher?.activeDevToolsServer == null) {
       return;
     }
    await Future.wait(<Future<void>>[
      for (final FlutterDevice device in flutterDevices)
        if (device.vmService != null)
          _callDevToolsUriExtension(device),
    ]);
  }

  Future<void> _callDevToolsUriExtension(
    FlutterDevice device,
  ) async {
    try {
      await _invokeRpcOnFirstView(
        'ext.flutter.activeDevToolsServerAddress',
        device: device,
        params: <String, dynamic>{
          'value': _devToolsLauncher.activeDevToolsServer.uri.toString(),
        },
      );
    } on Exception catch (e) {
      _logger.printError(
        'Failed to set DevTools server address: ${e.toString()}. Deep links to'
        ' DevTools will not show in Flutter errors.',
      );
    }
  }

  Future<void> _waitForExtensions(List<FlutterDevice> flutterDevices) async {
    await Future.wait(<Future<void>>[
      for (final FlutterDevice device in flutterDevices)
        if (device.vmService != null)
          waitForExtension(device.vmService.vmService, 'ext.flutter.connectedVmServiceUri'),
    ]);
  }

  Future<void> _callConnectedVmServiceUriExtension(List<FlutterDevice> flutterDevices) async {
    await Future.wait(<Future<void>>[
      for (final FlutterDevice device in flutterDevices)
        if (device.vmService != null)
          _callConnectedVmServiceExtension(device),
    ]);
  }

  Future<void> _callConnectedVmServiceExtension(FlutterDevice device) async {
    final Uri uri = device.vmService.httpAddress ?? device.vmService.wsAddress;
    if (uri == null) {
      return;
    }
    try {
      await _invokeRpcOnFirstView(
        'ext.flutter.connectedVmServiceUri',
        device: device,
        params: <String, dynamic>{
          'value': uri.toString(),
        },
      );
    } on Exception catch (e) {
      _logger.printError(e.toString());
      _logger.printError(
        'Failed to set vm service URI: ${e.toString()}. Deep links to DevTools'
        ' will not show in Flutter errors.',
      );
    }
  }

  Future<void> _invokeRpcOnFirstView(String method, {
    @required FlutterDevice device,
    @required Map<String, dynamic> params,
  }) async {
    final List<FlutterView> views = await device.vmService.getFlutterViews();
    if (views.isEmpty) {
      return;
    }
    await device.vmService
      .invokeFlutterExtensionRpcRaw(
        method,
        args: params,
        isolateId: views
          .first.uiIsolate.id
      );
  }

  @override
  Future<void> hotRestart(List<FlutterDevice> flutterDevices) async {
    await _waitForExtensions(flutterDevices);
    await Future.wait(<Future<void>>[
      _maybeCallDevToolsUriServiceExtension(flutterDevices),
      _callConnectedVmServiceUriExtension(flutterDevices),
    ]);
  }

  @override
  Future<void> shutdown() async {
    if (_devToolsLauncher == null || _shutdown || !_served) {
      return;
    }
    _shutdown = true;
    await _devToolsLauncher.close();
  }
}


@visibleForTesting
Future<void> waitForExtension(vm_service.VmService vmService, String extension) async {
  final Completer<void> completer = Completer<void>();
  try {
    await vmService.streamListen(vm_service.EventStreams.kExtension);
  } on Exception {
    // do nothing
  }
  StreamSubscription<vm_service.Event> extensionStream;
  extensionStream = vmService.onExtensionEvent.listen((vm_service.Event event) {
    if (event.json['extensionKind'] == 'Flutter.FrameworkInitialization') {
      // The 'Flutter.FrameworkInitialization' event is sent on hot restart
      // as well, so make sure we don't try to complete this twice.
      if (!completer.isCompleted) {
        completer.complete();
        extensionStream.cancel();
      }
    }
  });
  final vm_service.VM vm = await vmService.getVM();
  if (vm.isolates.isNotEmpty) {
    final vm_service.IsolateRef isolateRef = vm.isolates.first;
    final vm_service.Isolate isolate = await vmService.getIsolate(isolateRef.id);
    if (isolate.extensionRPCs.contains(extension)) {
      return;
    }
  }
  await completer.future;
}

@visibleForTesting
NoOpDevtoolsHandler createNoOpHandler(DevtoolsLauncher launcher, ResidentRunner runner, Logger logger) {
  return NoOpDevtoolsHandler();
}

@visibleForTesting
class NoOpDevtoolsHandler implements ResidentDevtoolsHandler {
  @override
  DevToolsServerAddress get activeDevToolsServer => null;

  @override
  Future<void> hotRestart(List<FlutterDevice> flutterDevices) async {
    return;
  }

  @override
  Future<void> serveAndAnnounceDevTools({Uri devToolsServerAddress, List<FlutterDevice> flutterDevices}) async {
    return;
  }

  @override
  Future<void> shutdown() async {
    return;
  }
}
