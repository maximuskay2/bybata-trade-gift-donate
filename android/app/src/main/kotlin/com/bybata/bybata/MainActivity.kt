package com.bybata.bybata

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.speech.RecognizerIntent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/// Must be FlutterFragmentActivity for local_auth / BiometricPrompt.
class MainActivity : FlutterFragmentActivity() {
    private var voiceResult: MethodChannel.Result? = null

    private val voiceLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { activityResult ->
        val pending = voiceResult
        voiceResult = null
        if (pending == null) return@registerForActivityResult
        if (activityResult.resultCode != Activity.RESULT_OK) {
            pending.success(null)
            return@registerForActivityResult
        }
        val matches = activityResult.data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
        pending.success(matches?.firstOrNull())
    }

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bybata/device_voice")
            .setMethodCallHandler { call, result ->
                if (call.method == "capture") {
                    startSystemVoice(result)
                } else {
                    result.notImplemented()
                }
            }
        val heroClip = HeroClipChannel(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bybata/hero_clip")
            .setMethodCallHandler { call, result ->
                heroClip.handle(call, result)
            }
    }

    /// The same system speech sheet the keyboard microphone uses.
    private fun startSystemVoice(result: MethodChannel.Result) {
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault().toLanguageTag())
            putExtra(RecognizerIntent.EXTRA_PROMPT, "Tell Bybata what you need")
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }
        if (intent.resolveActivity(packageManager) == null) {
            result.error("unavailable", "Voice typing is not available on this device.", null)
            return
        }
        if (voiceResult != null) {
            result.error("busy", "Voice typing is already open.", null)
            return
        }
        voiceResult = result
        try {
            voiceLauncher.launch(intent)
        } catch (e: Exception) {
            voiceResult = null
            result.error("unavailable", e.message, null)
        }
    }

    override fun onDestroy() {
        voiceResult?.success(null)
        voiceResult = null
        super.onDestroy()
    }
}
