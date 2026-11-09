package com.example.love_anniversary_app

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "love_anniversary_app/app",
        ).setMethodCallHandler { call, result ->
            if (call.method == "minimize") {
                result.success(moveTaskToBack(true))
            } else {
                result.notImplemented()
            }
        }
    }
}
