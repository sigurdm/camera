import 'dart:async';

import 'package:flutter/services.dart';

const MethodChannel _channel = const MethodChannel('camera');

class CameraId {
  final int surfaceId;

  CameraId._internal(int surfaceId) : surfaceId = surfaceId;

  static Future<List<String>> list() async {
    return await _channel.invokeMethod('list');
  }

  static Future<CameraId> create(String cameraName) async {
    int surfaceId =
        await _channel.invokeMethod('create', {'cameraName': cameraName});
    return new CameraId._internal(surfaceId);
  }

  Future<Null> dispose() async {
    await _channel.invokeMethod('dispose', {'surfaceId': surfaceId});
  }

  Future<Null> start() async {
    await _channel.invokeMethod('start', {'surfaceId': surfaceId});
  }

  Future<Null> stop() async {
    await _channel.invokeMethod('stop', {'surfaceId': surfaceId});
  }

}