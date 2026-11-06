package com.bybata.bybata

import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Must be FlutterFragmentActivity for local_auth / BiometricPrompt.
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            installSplashScreen()
        }
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "maps_config_android").setMethodCallHandler { call, result ->
            if (call.method == "getManifestKey") {
                try {
                    val appInfo = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                    val key = appInfo.metaData.getString("com.google.android.geo.API_KEY") ?: ""
                    result.success(key)
                } catch (e: Exception) {
                    result.error("manifest_error", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
