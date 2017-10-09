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
      child: new PlatformSurface(surfaceId: cameraId.surfaceId),
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

class CameraLifeCycle extends StatefulWidget {
  final CameraWidgetBuilder cameraWidgetBuilder;

  CameraLifeCycle(this.cameraWidgetBuilder);

  @override
  _PlayerLifeCycleState createState() =>
      new _PlayerLifeCycleState(cameraWidgetBuilder);
}

class _PlayerLifeCycleState extends State<CameraLifeCycle> {
  Future<CameraId> video;
  final CameraWidgetBuilder cameraWidgetBuilder;

  _PlayerLifeCycleState(this.cameraWidgetBuilder);

  @override
  void initState() {
    super.initState();
    video = CameraId.create("blah");
  }

  @override
  void dispose() {
    video.then((CameraId cameraId) {
      cameraId.dispose();
    });

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return cameraWidgetBuilder(context, video);
  }
}

class Cam extends StatefulWidget {
  @override
  CamState createState() {
    return new CamState();
  }
}

class CamState extends State<Cam> {
  CameraId camera;
  List<String> cameras;

  @override
  void initState() {
    CameraId.list().then((List<String> cameras) {
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
      for (String cameraId in cameras) {
        children.add(new RaisedButton(
            onPressed: () async {
              camera = await CameraId.create(cameraId);
              setState(() {});
            },
            child: new Text(cameraId)));
      }
    }

    if (camera != null) {
      children.add(new SizedBox(
          height: 200.0,
          width: 300.0,
          child: new PlatformSurface(surfaceId: camera.surfaceId)));
    }
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

//void main() {
//  runApp(
//    new MaterialApp(
//      home: new DefaultTabController(
//        length: 2,
//        child: new Scaffold(
//          appBar: new AppBar(
//            title: const Text('Tabbed AppBar'),
//            bottom: new TabBar(
//              isScrollable: true,
//              tabs: [
//                new Tab(icon: new Icon(Icons.arrow_upward)),
//                new Tab(icon: new Icon(Icons.rotate_right)),
//              ],
//            ),
//          ),
//          body: new TabBarView(
//            children: [
//              new CameraLifeCycle(
//                (BuildContext context, Future<CameraId> video) =>
//                    new FutureBuilder(
//                      future: video,
//                      builder: (BuildContext context,
//                          AsyncSnapshot<CameraId> snapshot) {
//                        switch (snapshot.connectionState) {
//                          case ConnectionState.none:
//                            return new Text('No video loaded');
//                          case ConnectionState.waiting:
//                            return new Text('Awaiting video...');
//                          default:
//                            if (snapshot.hasError)
//                              return new Text('Error: ${snapshot.error}');
//                            else
//                              return new Camera(snapshot.data);
//                        }
//                      },
//                    ),
//              ),
//              new Text("Hej"),
//            ],
//          ),
//        ),
//      ),
//    ),
//  );
//}
