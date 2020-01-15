// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'message.dart';

/// A Flutter Driver command that sends a string to the application and expects a
/// string response.
class RequestData extends Command {
  /// Create a command that sends a message.
  const RequestData(this.message, { Duration timeout }) : super(timeout: timeout);

  /// Deserializes this command from the value generated by [serialize].
  RequestData.deserialize(Map<String, String> params)
    : message = params['message'],
      super.deserialize(params);

  /// The message being sent from the test to the application.
  final String message;

  @override
  String get kind => 'request_data';

  @override
  bool get requiresRootWidgetAttached => false;

  @override
  Map<String, String> serialize() => super.serialize()..addAll(<String, String>{
    'message': message,
  });
}

/// The result of the [RequestData] command.
class RequestDataResult extends Result {
  /// Creates a result with the given [message].
  const RequestDataResult(this.message);

  /// The text extracted by the [RequestData] command.
  final String message;

  /// Deserializes the result from JSON.
  static RequestDataResult fromJson(Map<String, dynamic> json) {
    return RequestDataResult(json['message'] as String);
  }

  @override
  Map<String, dynamic> toJson() => <String, String>{
    'message': message,
  };
}
