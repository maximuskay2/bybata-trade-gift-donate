package com.bybata.bybata

import android.app.Activity
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.Uri
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.Crop
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.sqrt

/// Crops a hero clip to the subject and reports how hard the phone is moving.
@UnstableApi
class HeroClipChannel(private val activity: Activity) : SensorEventListener {
    private val sensorManager =
        activity.getSystemService(Activity.SENSOR_SERVICE) as SensorManager
    private val linear = sensorManager.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)
    private var magnitude = 0.0
    private var listening = false
    private var transformer: Transformer? = null

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "motion" -> {
                listen()
                result.success(magnitude)
            }
            "crop" -> crop(call, result)
            else -> result.notImplemented()
        }
    }

    private fun listen() {
        if (listening || linear == null) return
        sensorManager.registerListener(this, linear, SensorManager.SENSOR_DELAY_GAME)
        listening = true
    }

    override fun onSensorChanged(event: SensorEvent) {
        val x = event.values[0].toDouble()
        val y = event.values[1].toDouble()
        val z = event.values[2].toDouble()
        magnitude = sqrt(x * x + y * y + z * z)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun crop(call: MethodCall, result: MethodChannel.Result) {
        val source = call.argument<String>("source")
        val dest = call.argument<String>("dest")
        val left = call.argument<Double>("left")
        val top = call.argument<Double>("top")
        val width = call.argument<Double>("width")
        val height = call.argument<Double>("height")
        if (source.isNullOrEmpty() || dest.isNullOrEmpty() ||
            left == null || top == null || width == null || height == null
        ) {
            result.error("args", "Missing crop arguments", null)
            return
        }
        val leftN = (-1.0 + 2.0 * left).toFloat()
        val rightN = (-1.0 + 2.0 * (left + width)).toFloat()
        val topN = (1.0 - 2.0 * top).toFloat()
        val bottomN = (1.0 - 2.0 * (top + height)).toFloat()
        val crop = Crop(leftN, rightN, bottomN, topN)
        val edited = EditedMediaItem.Builder(MediaItem.fromUri(Uri.parse("file://$source")))
            .setEffects(Effects(emptyList(), listOf(crop)))
            .build()
        val exporter = Transformer.Builder(activity).build()
        transformer = exporter
        exporter.addListener(object : Transformer.Listener {
            override fun onCompleted(composition: androidx.media3.transformer.Composition, exportResult: ExportResult) {
                activity.runOnUiThread { result.success(dest) }
            }

            override fun onError(
                composition: androidx.media3.transformer.Composition,
                exportResult: ExportResult,
                exportException: ExportException,
            ) {
                activity.runOnUiThread {
                    result.error("crop", exportException.message, null)
                }
            }
        })
        exporter.start(edited, dest)
    }
}
