package com.yourcompany.camera;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageManager;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCaptureSession;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;

import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import io.flutter.view.FlutterView;

import android.hardware.camera2.CaptureRequest;
import android.support.annotation.NonNull;
import android.util.Log;
import android.view.Surface;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class CameraPlugin implements MethodCallHandler {

    private static CameraManager cameraManager;
    private static Activity activity;

    private class Cam {
        private final FlutterView.SurfaceTextureHandle textureHandle;

        Cam(final FlutterView.SurfaceTextureHandle textureHandle, String cameraName, final Result result) {
            this.textureHandle = textureHandle;
            activity.requestPermissions(new String[] {Manifest.permission.CAMERA}, 100);
            if (activity.checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
                result.error("No camera permission", "C", null);
            } else {
                try {
                    cameraManager.openCamera(cameraName, new CameraDevice.StateCallback() {
                        @Override
                        public void onOpened(CameraDevice cameraDevice) {
                            final Surface surface = new Surface(textureHandle.getSurfaceTexture());
                            List<Surface> surfaceList = new ArrayList<Surface>();
                            surfaceList.add(surface);
                            final CaptureRequest.Builder previewRequestBuilder;
                            try {
                                previewRequestBuilder = cameraDevice.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW);
                                cameraDevice.createCaptureSession(surfaceList, new CameraCaptureSession.StateCallback() {
                                    @Override
                                    public void onConfigured(@NonNull CameraCaptureSession cameraCaptureSession) {
                                        previewRequestBuilder.set(CaptureRequest.CONTROL_AF_MODE,
                                                CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE);
                                        previewRequestBuilder.addTarget(surface);
                                        CaptureRequest previewRequest = previewRequestBuilder.build();
                                        try {
                                            cameraCaptureSession.setRepeatingRequest(previewRequest,
                                                    new CameraCaptureSession.CaptureCallback() {
                                                        @Override
                                                        public void onCaptureBufferLost(@NonNull CameraCaptureSession session, @NonNull CaptureRequest request, @NonNull Surface target, long frameNumber) {
                                                            super.onCaptureBufferLost(session, request, target, frameNumber);
                                                            Log.e(TAG, "Lost capture buffer");
                                                        }
                                                    }, null);
                                        } catch (CameraAccessException e) {
                                            result.error("EEE", e.toString(), null);
                                            return;
                                        }
                                        result.success(textureHandle.getSurfaceId());
                                    }

                                    @Override
                                    public void onConfigureFailed(@NonNull CameraCaptureSession cameraCaptureSession) {
                                        result.error("A", "B", null);
                                    }
                                }, null);
                            } catch (CameraAccessException e) {
                                result.error(e.toString(), "BLAGH", null);
                                return;
                            }
                        }

                        @Override
                        public void onDisconnected(CameraDevice cameraDevice) {

                        }

                        @Override
                        public void onError(CameraDevice cameraDevice, int i) {

                        }
                    }, null);
                } catch (CameraAccessException e) {
                    result.error(e.toString(), "BLAGH", null);
                    return;
                }
            }
        }

        public void play() {

        }

        public void pause() {

        }

        public void seekTo(int location) {
        }

        public int getDuration() {
            return 2;
        }

        public long getSurfaceId() {
            return textureHandle.getSurfaceId();
        }

        public void dispose() {
            textureHandle.release();
        }
    }

    public static void registerWith(Registrar registrar) {
        final MethodChannel channel = new MethodChannel(registrar.messenger(), "camera");
        cameraManager = (CameraManager) registrar.activity().getSystemService(Context.CAMERA_SERVICE);
        activity = registrar.activity();
        channel.setMethodCallHandler(new CameraPlugin(registrar.view()));
    }

    private CameraPlugin(FlutterView view) {
        this.view = view;
    }

    static final String TAG = "camera plugin";
    static private Map<Long, Cam> cams = new HashMap<>();
    private final FlutterView view;

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        if (call.method.equals("list")) {
            try {
                String[] cameraNames = cameraManager.getCameraIdList();
                List<String> c = Arrays.asList(cameraNames);
                for (String s : c) {
                    Log.e(TAG, "Got " + s);
                }
                result.success(c);
            } catch (CameraAccessException e) {
                result.error(e.toString(), "Blah", null);
                Log.e(TAG, e.toString());
            }
        } else if (call.method.equals("create")) {
            Cam cam = new Cam(view.createSurfaceTexture(), (String) call.argument("cameraName"), result);
            cams.put(cam.getSurfaceId(), cam);
        } else if (call.method.equals("play")) {
            long surfaceId = ((Number) call.argument("surfaceId")).longValue();
            Cam cam = cams.get(surfaceId);
            cam.play();
            result.success(true);
        } else if (call.method.equals("pause")) {
            long surfaceId = ((Number) call.argument("surfaceId")).longValue();
            Cam cam = cams.get(surfaceId);
            cam.pause();
            result.success(true);
        } else if (call.method.equals("seekTo")) {
            long surfaceId = ((Number) call.argument("surfaceId")).longValue();
            int location = ((Number) call.argument("location")).intValue();
            Cam cam = cams.get(surfaceId);
            cam.seekTo(location);
            result.success(true);
        } else if (call.method.equals("duration")) {
            long surfaceId = ((Number) call.argument("surfaceId")).longValue();
            Cam cam = cams.get(surfaceId);
            result.success(cam.getDuration());
        } else if (call.method.equals("dispose")) {
            long surfaceId = ((Number) call.argument("surfaceId")).longValue();
            Cam cam = cams.remove(surfaceId);
            if (cam != null) {
                cam.dispose();
            }
            result.success(true);
        } else {
            result.notImplemented();
        }
    }
}
