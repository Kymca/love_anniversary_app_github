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
                    val info = packageManager.getPackageInfo(packageName, 0)
                    result.success(
                        mapOf(
                            "packageName" to packageName,
                            "versionName" to info.versionName,
                            "versionCode" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                info.longVersionCode.toInt()
                            } else {
                                @Suppress("DEPRECATION")
                                info.versionCode
                            },
                        ),
                    )
                }
                "canInstallPackages" -> result.success(canInstallPackages())
                "openUnknownSourcesSettings" -> openUnknownSourcesSettings(result)
                "installApk" -> installApk(call.argument<String>("path"), result)
                else -> result.notImplemented()
            }
        }
    }

    private fun canInstallPackages(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()

    private fun openUnknownSourcesSettings(
        result: MethodChannel.Result,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.error("unsupported_android_version", "Android 8 or later is required.", null)
            return
        }
        val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:$packageName"),
        )
        startActivity(intent)
        result.success(null)
    }

    private fun installApk(path: String?, result: MethodChannel.Result) {
        if (!canInstallPackages()) {
            result.success("permission_required")
            return
        }
        if (path.isNullOrBlank()) {
            result.error("invalid_apk_path", "APK path is missing.", null)
            return
        }

        val updateDirectory = File(cacheDir, "app_updates").canonicalFile
        val apkFile = File(path).canonicalFile
        if (!apkFile.path.startsWith(updateDirectory.path + File.separator) ||
            !apkFile.isFile ||
            !apkFile.name.endsWith(".apk", ignoreCase = true)
        ) {
            result.error("invalid_apk_path", "APK file is outside the update cache.", null)
            return
        }

        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            apkFile,
        )
        val intent = Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(intent)
        result.success("started")
    }
}
