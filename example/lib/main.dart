import 'dart:math' show sin;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class Camera extends StatefulWidget {
  final CameraId cameraId;

  Camera(this.cameraId);

  @override
  State createState() {
    return new _CameraState(cameraId);
  }
}

class _CameraState extends State<StatefulWidget> {
  final CameraId cameraId;
  bool isPlaying = true;

  _CameraState(this.cameraId);

  @override
  void initState() {
    super.initState();
    if (isPlaying) cameraId.start();
  }

  @override
  void deactivate() {
    if (isPlaying) cameraId.stop();
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    return new GestureDetector(
      child: new Texture(textureId: cameraId.textureId),
      onTap: () {
        isPlaying = !isPlaying;
        setState(() {});
        if (isPlaying) {
          cameraId.start();
        } else {
          cameraId.stop();
        }
      },
    );
  }
}

typedef Widget CameraWidgetBuilder(
    BuildContext context, Future<CameraId> cameraId);

class Cam extends StatefulWidget {
  @override
  CamState createState() {
    return new CamState();
  }
}

class CamState extends State<Cam> {
  CameraId camera;
  List<CameraDescription> cameras;
  bool started;

  @override
  void initState() {
    availableCameras().then((List<CameraDescription> cameras) {
      setState(() {
        this.cameras = cameras;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = <Widget>[];
    if (cameras == null) {
      children.add(new Text("No cameras yet"));
    } else {
      for (CameraDescription cameraDescription in cameras) {
        children.add(new RaisedButton(
            onPressed: () async {
              if (camera != null) {
                camera.dispose();
              }
              camera = null;
              setState(() {});
              camera = await cameraDescription.open();
              setState(() {});
              camera.start();
              started = true;
            },
            child: new Text(
                "${cameraDescription.name} ${cameraDescription.lensDirection}")));
      }
    }

    children.add(new GestureDetector(
        onTap: () {
          if (started) {
            started = false;
            camera.stop();
          } else {
            started = true;
            camera.start();
          }
        },
        child: new AspectRatio(
            aspectRatio: 3 / 2,
            child: (camera == null)
                ? new Text("Tap a camera")
                : new Texture(textureId: camera.textureId))));
    return new Column(children: children);
  }
}

void main() {
  runApp(new MaterialApp(
      home: new Scaffold(
    appBar: new AppBar(
      title: new Text("Camera example"),
    ),
    body: new Cam(),
  )));
}
