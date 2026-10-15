package com.kaizenteam

import android.content.Intent
import android.view.OrientationEventListener
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var trainingVideoCaptureBridge: TrainingVideoCaptureBridge
    private lateinit var googleBrowserAuthorizationBridge: GoogleBrowserAuthorizationBridge
    private var isVideoFullscreen = false
    private var previousSystemBarsBehavior: Int? = null
    private var portraitOrientationListener: OrientationEventListener? = null
    private var pendingPortraitResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        if (!this::trainingVideoCaptureBridge.isInitialized) {
            trainingVideoCaptureBridge = TrainingVideoCaptureBridge(this)
        }

        if (!this::googleBrowserAuthorizationBridge.isInitialized) {
            googleBrowserAuthorizationBridge = GoogleBrowserAuthorizationBridge(this)
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kaizenteams/google_browser_authorization",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "authorize" -> googleBrowserAuthorizationBridge.authorize(
                    call.argument<String>("authorizationUrl"),
                    call.argument<String>("redirectUri"),
                    call.argument<String>("requestId"),
                    result,
                )
                "cancel" -> {
                    googleBrowserAuthorizationBridge.cancel(call.argument<String>("requestId"))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TRAINING_VIDEO_CAPTURE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "captureTrainingVideoWithSystemCamera" -> {
                    trainingVideoCaptureBridge.captureVideoWithSystemCamera(result)
                }

                "restorePendingTrainingVideoCapture" -> {
                    trainingVideoCaptureBridge.restorePendingCaptureIfNeeded(result)
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VIDEO_FULLSCREEN_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setFullscreen" -> {
                    isVideoFullscreen = call.argument<Boolean>("enabled") == true
                    applyVideoFullscreen()
                    result.success(null)
                }
                "waitForPortrait" -> waitForDevicePortrait(result)
                "cancelWaitForPortrait" -> {
                    finishPortraitWait(false)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun waitForDevicePortrait(result: MethodChannel.Result) {
        finishPortraitWait(false)
        val listener = object : OrientationEventListener(this) {
            override fun onOrientationChanged(orientation: Int) {
                // Sensor orientation remains physical when the activity is locked.
                if (orientation in 0..20 || orientation in 340..359) {
                    finishPortraitWait(true)
                }
            }
        }
        if (!listener.canDetectOrientation()) {
            result.success(false)
            return
        }
        pendingPortraitResult = result
        portraitOrientationListener = listener
        listener.enable()
    }

    private fun finishPortraitWait(isPortrait: Boolean) {
        portraitOrientationListener?.disable()
        portraitOrientationListener = null
        val result = pendingPortraitResult
        pendingPortraitResult = null
        result?.success(isPortrait)
    }

    override fun onPause() {
        portraitOrientationListener?.disable()
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        portraitOrientationListener?.enable()
    }

    override fun onDestroy() {
        finishPortraitWait(false)
        if (this::googleBrowserAuthorizationBridge.isInitialized) {
            googleBrowserAuthorizationBridge.dispose()
        }
        super.onDestroy()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus && isVideoFullscreen) {
            applyVideoFullscreen()
        }
    }

    private fun applyVideoFullscreen() {
        val controller = WindowCompat.getInsetsController(window, window.decorView)
        if (isVideoFullscreen) {
            if (previousSystemBarsBehavior == null) {
                previousSystemBarsBehavior = controller.systemBarsBehavior
            }
            controller.systemBarsBehavior =
                WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            controller.hide(WindowInsetsCompat.Type.systemBars())
        } else {
            previousSystemBarsBehavior?.let { controller.systemBarsBehavior = it }
            previousSystemBarsBehavior = null
            controller.show(WindowInsetsCompat.Type.systemBars())
        }
    }

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ) {
        if (this::googleBrowserAuthorizationBridge.isInitialized &&
            googleBrowserAuthorizationBridge.handleActivityResult(requestCode, resultCode, data)
        ) {
            return
        }

        if (this::trainingVideoCaptureBridge.isInitialized &&
            trainingVideoCaptureBridge.handleActivityResult(requestCode, resultCode, data)
        ) {
            return
        }

        super.onActivityResult(requestCode, resultCode, data)
    }

    private companion object {
        const val VIDEO_FULLSCREEN_CHANNEL = "kaizenteams/video_fullscreen"
        const val TRAINING_VIDEO_CAPTURE_CHANNEL =
            "kaizenteams/training_video_capture"
    }
}
