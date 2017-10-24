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

Future<List<CameraDescription>> availableCameras() async {
  CameraFormat decodeFormat(Map<String, int> json) {
    return new CameraFormat(
        json['width'], json['height'], json['frameDuration']);
  }

  try {
    List<Map<String, String>> cameras = await _channel.invokeMethod('list');
    return cameras.map((Map<String, dynamic> camera) {
      final previewFormats =
          (camera['previewFormats'] as List<Map<String, int>>)
              .map(decodeFormat)
              .toList(growable: false);
      final captureFormats =
          (camera['captureFormats'] as List<Map<String, int>>)
              .map(decodeFormat)
              .toList(growable: false);
      return new CameraDescription(
          camera['name'],
          _parseCameraLensDirection(camera['lensFacing']),
          previewFormats,
          captureFormats);
    }).toList();
  } on PlatformException catch (e) {
    throw new CameraException(e.code, e.message);
  }
}

class CameraFormat {
  final int width;
  final int height;
  final int frameDuration;
  CameraFormat(this.width, this.height, this.frameDuration);

  @override
  String toString() {
    return "${width}x$height frame duration $frameDuration ns";
  }
}

class CameraDescription {
  final String name;
  final CameraLensDirection lensDirection;
  final List<CameraFormat> previewFormats;
  final List<CameraFormat> captureFormats;
  CameraDescription(
      this.name, this.lensDirection, this.previewFormats, this.captureFormats);

  Future<CameraId> open(CameraFormat previewFormat, CameraFormat captureFormat) async {
    try {
      int surfaceId = await _channel.invokeMethod('create',
          {'cameraName': name, 'previewWidth': previewFormat.width, 'previewHeight': previewFormat.height, 'captureWidth': captureFormat.width, 'captureHeight': captureFormat.height});
      return new CameraId._internal(surfaceId);
    } on PlatformException catch (e) {
      throw new CameraException(e.code, e.message);
    }
  }

  @override
  String toString() {
    return "$name captureFormats=$captureFormats, previewFormats=$previewFormats";
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

  Future<String> capture(String filename) async {
    try {
      return await _channel.invokeMethod('capture', {'textureId': textureId, 'filename': filename});
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
