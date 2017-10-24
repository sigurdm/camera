import 'dart:async';
import 'dart:io';

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
  bool opening = false;
  CameraId camera;
  List<CameraDescription> cameras;
  bool started;
  String filename;
  int pictureCount = 0;

  @override
  void initState() {
    availableCameras().then((List<CameraDescription> cameras) {
      setState(() {
        this.cameras = cameras;
        print(cameras[0].captureFormats);

        print(cameras[1].captureFormats);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> cameraList = <Widget>[];
    if (cameras == null) {
      cameraList.add(new Text("No cameras yet"));
    } else {
      for (CameraDescription cameraDescription in cameras) {
        cameraList.add(new RaisedButton(
            onPressed: () async {
              if (opening) return;
              if (camera != null) {
                camera.dispose();
              }
              camera = null;
              setState(() {});
              CameraFormat previewFormat =
                  cameraDescription.previewFormats.first;
              CameraFormat captureFormat =
                  cameraDescription.captureFormats.first;
              opening = true;
              camera =
                  await cameraDescription.open(previewFormat, captureFormat);
              opening = false;
              setState(() {});
              camera.start();
              started = true;
            },
            child: new Text(
                '${cameraDescription.name} ${cameraDescription.lensDirection}')));
      }
    }
    List<Widget> rowChildren = <Widget>[new Column(children: cameraList)];
    if (filename != null) {
      rowChildren.add(new SizedBox(
        child: new Image.file(new File(filename)),
        width: 64.0,
        height: 64.0,
      ));
    }

    List<Widget> columnChildren = <Widget>[];
    columnChildren.add(new Row(children: rowChildren));
    columnChildren.add(new GestureDetector(
        onTap: () {
          print("Tap");
          if (started) {
            started = false;
            camera.stop();
          } else {
            started = true;
            camera.start();
          }
        },
        onDoubleTap: () {
          if (started) {
            camera.capture("picture${pictureCount++}").then((String filename) {
              setState(() {
                print(filename);
                this.filename = filename;
              });
            });
          }
        },
        child: new SizedBox(width: 200.0, child: new AspectRatio(
            aspectRatio: 2 / 3,
            child: (camera == null)
                ? new Text("Tap a camera")
                : new Texture(textureId: camera.textureId)))));
    return new Column(children: columnChildren);
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
