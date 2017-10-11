import 'dart:async';

import 'package:flutter/services.dart';

const MethodChannel _channel = const MethodChannel('camera');

enum CameraLensDirection { front, back, external, unknown }

CameraLensDirection _parseCameraLensDirection(String string) {
  switch (string) {
    case 'front':
      return CameraLensDirection.front;
    case 'back':
      return CameraLensDirection.back;
    case 'external':
      return CameraLensDirection.external;
    default:
      return CameraLensDirection.unknown;
  }
}

Future<List<CameraDescription>> getAll() async {
  List<Map<String, String>> cameras = await _channel.invokeMethod('list');
  return cameras.map((Map<String, String> camera) {
    return new CameraDescription(
        camera['name'], _parseCameraLensDirection(camera['lens_facing']));
  }).toList();
}

Future<List<CameraDescription>> availableCameras() async {
  try {
    List<Map<String, String>> cameras = await _channel.invokeMethod('list');
    return cameras.map((Map<String, String> camera) {
      return new CameraDescription(
          camera['name'], _parseCameraLensDirection(camera['lens_facing']));
    }).toList();
  } on PlatformException catch (e) {
    throw new CameraException(e.code, e.message);
  }
}

class CameraDescription {
  final String name;
  CameraLensDirection lensDirection;
  CameraDescription(this.name, this.lensDirection);

  Future<CameraId> open() async {
    try {
      int surfaceId =
          await _channel.invokeMethod('create', {'cameraName': name});
      return new CameraId._internal(surfaceId);
    } on PlatformException catch (e) {
      throw new CameraException(e.code, e.message);
    }
  }
}

enum CameraEvent { error, disconnected }

CameraEvent _parseCameraEvent(String string) {
  switch (string) {
    case 'error':
      return CameraEvent.error;
    case 'disconnected':
      return CameraEvent.disconnected;
    default:
      throw new ArgumentError("$string is not a valid camera event");
  }
}

class CameraException implements Exception {
  String code;
  String description;
  CameraException(this.code, this.description);
  String toString() => "CameraException($code, $description)";
}

class CameraId {
  final int textureId;

  CameraId._internal(int surfaceId)
      : textureId = surfaceId,
        events = new EventChannel('cameraPlugin/cameraEvents$surfaceId')
            .receiveBroadcastStream()
            .map(_parseCameraEvent);

  final Stream<CameraEvent> events;

  Future<Null> dispose() async {
    try {
      await _channel.invokeMethod('dispose', {'textureId': textureId});
    } on PlatformException catch (e) {
      throw new CameraException(e.code, e.message);
    }
  }

  Future<Null> start() async {
    try {
      await _channel.invokeMethod('start', {'textureId': textureId});
    } on PlatformException catch (e) {
      throw new CameraException(e.code, e.message);
    }
  }

  Future<Null> stop() async {
    try {
      await _channel.invokeMethod('stop', {'textureId': textureId});
    } on PlatformException catch (e) {
      throw new CameraException(e.code, e.message);
    }
  }
}
