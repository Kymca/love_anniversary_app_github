package com.example.love_anniversary_app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File
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
            when (call.method) {
                "minimize" -> result.success(moveTaskToBack(true))
                "getAppVersion" -> {
                    val packageInfo = packageManager.getPackageInfo(packageName, 0)
                    val buildNumber = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        packageInfo.longVersionCode
                    } else {
                        @Suppress("DEPRECATION")
                        packageInfo.versionCode.toLong()
                    }
                    result.success(
                        mapOf(
                            "versionName" to packageInfo.versionName,
                            "buildNumber" to buildNumber.toString(),
                        ),
                    )
                }
                "canRequestPackageInstalls" -> {
                    result.success(
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                            packageManager.canRequestPackageInstalls(),
                    )
                }
                "requestInstallPermission" -> {
                    startActivity(
                        Intent(
                            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:$packageName"),
                        ),
                    )
                    result.success(null)
                }
                "installApk" -> installApk(call.argument<String>("path"), result)
                else -> result.notImplemented()
            }
        }
    }

    private fun installApk(path: String?, result: MethodChannel.Result) {
        if (path == null) {
            result.error("invalid_path", "APK path is missing.", null)
            return
        }
        val updatesDirectory = File(cacheDir, "updates").canonicalFile
        val apk = File(path).canonicalFile
        if (!apk.path.startsWith("${updatesDirectory.path}${File.separator}") ||
            !apk.isFile
        ) {
            result.error("invalid_path", "APK is outside the update cache.", null)
            return
        }

        val apkUri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            apk,
        )
        startActivity(
            Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(apkUri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            },
        )
        result.success(null)
    }
}
