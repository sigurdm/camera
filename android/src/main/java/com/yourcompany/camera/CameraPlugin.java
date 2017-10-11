package com.yourcompany.camera;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageManager;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCaptureSession;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;

import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import io.flutter.view.FlutterView;

import android.hardware.camera2.CameraMetadata;
import android.hardware.camera2.CaptureRequest;
import android.support.annotation.NonNull;
import android.util.Log;
import android.view.Surface;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class CameraPlugin implements MethodCallHandler {

    private static CameraManager cameraManager;

    private Activity activity;
    private Registrar registrar;

    // The code to run after requesting the permission.
    private Runnable permissionContinuation;

    private static final int requestId = 513469796;

    private class CameraRequestPermissionListener implements PluginRegistry.RequestPermissionResultListener {
        @Override
        public boolean onRequestPermissionResult(int id, String[] permissions, int[] grantResults) {
            if (id == requestId) {
                permissionContinuation.run();
            }
            return false;
        }
    }

    private class Cam {
        private final FlutterView.SurfaceTextureHandle textureHandle;
        private CameraDevice cameraDevice;
        private Surface surface;
        private CameraCaptureSession cameraCaptureSession;
        private EventChannel.EventSink eventSink;
        private int orientation;

        Cam(final EventChannel eventChannel, final FlutterView.SurfaceTextureHandle textureHandle, final String cameraName, final Result result, int orientation) {
            this.orientation = orientation;
            this.textureHandle = textureHandle;
            eventChannel.setStreamHandler(new EventChannel.StreamHandler() {
                @Override
                public void onListen(Object arguments, EventChannel.EventSink eventSink) {
                    Cam.this.eventSink = eventSink;
                }

                @Override
                public void onCancel(Object arguments) {
                    Cam.this.eventSink = null;
                }
            });
            if (permissionContinuation != null) {
                result.error("cameraPermission", "Camera permission request ongoing", null);
            }
            permissionContinuation = new Runnable() {
                @Override
                public void run() {
                    permissionContinuation = null;
                    if (activity.checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
                        result.error("cameraPermission", "Camera permission not granted", null);
                    } else {
                        try {
                            cameraManager.openCamera(cameraName, new CameraDevice.StateCallback() {
                                @Override
                                public void onOpened(CameraDevice cameraDevice) {
                                    Cam.this.cameraDevice = cameraDevice;
                                    surface = new Surface(textureHandle.getSurfaceTexture());
                                    List<Surface> surfaceList = new ArrayList<Surface>();
                                    surfaceList.add(surface);
                                    try {
                                        cameraDevice.createCaptureSession(surfaceList, new CameraCaptureSession.StateCallback() {
                                            @Override
                                            public void onConfigured(@NonNull CameraCaptureSession cameraCaptureSession) {
                                                Cam.this.cameraCaptureSession = cameraCaptureSession;
                                                result.success(textureHandle.getId());
                                            }

                                            @Override
                                            public void onConfigureFailed(@NonNull CameraCaptureSession cameraCaptureSession) {
                                                result.error("configureFailed", "Failed to configure camera session", null);
                                            }
                                        }, null);
                                    } catch (CameraAccessException e) {
                                        result.error("cameraAccess", e.toString(), null);
                                        return;
                                    }
                                }

                                @Override
                                public void onDisconnected(@NonNull CameraDevice cameraDevice) {
                                    if (eventSink != null) {
                                        eventSink.success("disconnected");
                                    }
                                }

                                @Override
                                public void onError(@NonNull CameraDevice cameraDevice, int i) {
                                    if (eventSink != null) {
                                        // TODO (sigurdm): Add error description.
                                        eventSink.success("error");
                                    }
                                }
                            }, null);
                        } catch (CameraAccessException e) {
                            result.error("cameraAccess", e.toString(), null);
                            return;
                        }

                    }
                }
            };
            activity.requestPermissions(new String[]{Manifest.permission.CAMERA}, requestId);
        }

        public void start() throws CameraAccessException {
            assert (cameraDevice != null);

            final CaptureRequest.Builder previewRequestBuilder = cameraDevice.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW);
            previewRequestBuilder.set(CaptureRequest.CONTROL_AF_MODE,
                    CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE);

            previewRequestBuilder.set(CaptureRequest.JPEG_ORIENTATION, orientation);
            previewRequestBuilder.addTarget(surface);
            CaptureRequest previewRequest = previewRequestBuilder.build();
            cameraCaptureSession.setRepeatingRequest(previewRequest,
                    new CameraCaptureSession.CaptureCallback() {
                        @Override
                        public void onCaptureBufferLost(@NonNull CameraCaptureSession session, @NonNull CaptureRequest request, @NonNull Surface target, long frameNumber) {
                            super.onCaptureBufferLost(session, request, target, frameNumber);
                            Log.e(TAG, "Lost capture buffer");
                        }
                    }, null);
        }

        public void stop() throws CameraAccessException {
            cameraCaptureSession.abortCaptures();
        }

        public long getTextureId() {
            return textureHandle.getId();
        }

        public void dispose() {
            cameraCaptureSession.close();
            cameraDevice.close();
            cameraDevice = null;
            textureHandle.release();
        }
    }

    public static void registerWith(Registrar registrar) {
        final MethodChannel channel = new MethodChannel(registrar.messenger(), "camera");
        cameraManager = (CameraManager) registrar.activity().getSystemService(Context.CAMERA_SERVICE);
        channel.setMethodCallHandler(new CameraPlugin(registrar, registrar.view(), registrar.activity()));
    }

    private CameraPlugin(Registrar registrar, FlutterView view, Activity activity) {
        this.registrar = registrar;
        registrar.addRequestPermissionResultListener(new CameraRequestPermissionListener());
        this.view = view;
        this.activity = activity;
    }

    static final String TAG = "camera plugin";
    static private Map<Long, Cam> cams = new HashMap<>();
    private final FlutterView view;

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        if (call.method.equals("list")) {
            try {
                String[] cameraNames = cameraManager.getCameraIdList();
                List<Map<String, String>> cameras = new ArrayList<>();
                for (String cameraName : cameraNames) {
                    HashMap<String, String> details = new HashMap<>();
                    CameraCharacteristics characteristics = cameraManager.getCameraCharacteristics(cameraName);
                    details.put("name", cameraName);
                    @SuppressWarnings("ConstantConditions")
                    int lens_facing = characteristics.get(CameraCharacteristics.LENS_FACING);
                    switch (lens_facing) {
                        case CameraMetadata.LENS_FACING_FRONT:
                            details.put("lens_facing", "front");
                            break;
                        case CameraMetadata.LENS_FACING_BACK:
                            details.put("lens_facing", "back");
                            break;
                        case CameraMetadata.LENS_FACING_EXTERNAL:
                            details.put("lens_facing", "external");
                            break;
                    }
                    cameras.add(details);
                }
                result.success(cameras);
            } catch (CameraAccessException e) {
                result.error("cameraAccess", e.toString(), null);
            }
        } else if (call.method.equals("create")) {
            FlutterView.SurfaceTextureHandle surfaceTexture = view.createSurfaceTexture();
            final EventChannel eventChannel =
                    new EventChannel(registrar.messenger(), "cameraPlugin/cameraEvents" + surfaceTexture.getId());
            String cameraName = (String) call.argument("cameraName");
            Cam cam = null;
            try {
                cam = new Cam(eventChannel, surfaceTexture, cameraName, result, cameraManager.getCameraCharacteristics(cameraName).get(CameraCharacteristics.SENSOR_ORIENTATION));
            } catch (CameraAccessException e) {
                result.error("cameraAccess", e.toString(), null);
            }
            cams.put(cam.getTextureId(), cam);
        } else if (call.method.equals("start")) {
            long textureId = ((Number) call.argument("textureId")).longValue();
            Cam cam = cams.get(textureId);
            try {
                cam.start();
                result.success(true);
            } catch (CameraAccessException e) {
                result.error("cameraAccess", e.toString(), null);
            }
        } else if (call.method.equals("stop")) {
            long textureId = ((Number) call.argument("textureId")).longValue();
            Cam cam = cams.get(textureId);
            try {
                cam.stop();
            } catch (CameraAccessException e) {
                result.error("cameraAccess", e.toString(), null);
            }
            result.success(true);
        } else if (call.method.equals("dispose")) {
            long textureId = ((Number) call.argument("textureId")).longValue();
            Cam cam = cams.remove(textureId);
            if (cam != null) {
                cam.dispose();
            }
            result.success(true);
        } else {
            result.notImplemented();
        }
    }
}
