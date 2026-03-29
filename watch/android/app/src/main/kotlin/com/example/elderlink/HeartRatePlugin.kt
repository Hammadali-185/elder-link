package com.example.elderlink

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class HeartRatePlugin : FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    SensorEventListener,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    private lateinit var context: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var eventSink: EventChannel.EventSink? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    private var sensorManager: SensorManager? = null
    private var heartRateSensor: Sensor? = null
    private var isSensorAvailable = false
    private var isMonitoring = false

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        refreshSensorState()

        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "heart_rate/methods")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "heart_rate/stream")
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopMonitoring()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detachFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        detachFromActivity()
    }

    private fun detachFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkSensor" -> {
                refreshSensorState()
                result.success(isSensorAvailable)
            }
            "checkPermissions" -> result.success(hasRequiredPermissions())
            "ensurePermissions" -> ensurePermissions(result)
            "startMonitoring" -> {
                refreshSensorState()
                if (!isSensorAvailable) {
                    result.error("sensor_unavailable", "Heart-rate sensor is not available on this watch.", null)
                    return
                }
                if (!hasRequiredPermissions()) {
                    result.error("permission_denied", "Heart-rate permission is not granted.", null)
                    return
                }
                val started = startMonitoringInternal()
                if (started) {
                    result.success(true)
                } else {
                    result.error("monitoring_failed", "Failed to start heart-rate monitoring.", null)
                }
            }
            "stopMonitoring" -> {
                stopMonitoring()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        stopMonitoring()
        eventSink = null
    }

    private fun refreshSensorState() {
        heartRateSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_HEART_RATE)
        isSensorAvailable = heartRateSensor != null
        if (isSensorAvailable) {
            Log.d(TAG, "Heart-rate sensor detected")
        } else {
            Log.w(TAG, "Heart-rate sensor not available")
        }
    }

    private fun ensurePermissions(result: MethodChannel.Result) {
        if (hasRequiredPermissions()) {
            result.success(true)
            return
        }

        val hostActivity = activity
        if (hostActivity == null) {
            result.error("activity_unavailable", "No activity available for permission request.", null)
            return
        }
        if (pendingPermissionResult != null) {
            result.error("permission_pending", "A heart-rate permission request is already in progress.", null)
            return
        }

        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            hostActivity,
            requiredPermissions(),
            REQUEST_CODE_PERMISSIONS
        )
    }

    private fun hasRequiredPermissions(): Boolean {
        return requiredPermissions().any { permission ->
            ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requiredPermissions(): Array<String> {
        return arrayOf(
            Manifest.permission.BODY_SENSORS,
            PERMISSION_READ_HEART_RATE,
        )
    }

    private fun startMonitoringInternal(): Boolean {
        if (isMonitoring) return true

        val sensor = heartRateSensor ?: return false
        val success = sensorManager?.registerListener(
            this,
            sensor,
            SensorManager.SENSOR_DELAY_FASTEST,
            0
        ) ?: false

        isMonitoring = success
        if (!success) {
            Log.e(TAG, "Failed to register heart-rate listener")
        }
        return success
    }

    private fun stopMonitoring() {
        if (!isMonitoring) return
        sensorManager?.unregisterListener(this)
        isMonitoring = false
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type != Sensor.TYPE_HEART_RATE || event.values.isEmpty()) return

        val heartRate = event.values[0].toInt()
        if (heartRate <= 0) {
            return
        }

        eventSink?.success(heartRate)
        if (heartRate < 50 || heartRate > 110) {
            Log.w(TAG, "Abnormal heart rate detected: $heartRate bpm")
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        when (accuracy) {
            SensorManager.SENSOR_STATUS_UNRELIABLE ->
                Log.w(TAG, "Heart-rate sensor accuracy: UNRELIABLE")
            SensorManager.SENSOR_STATUS_ACCURACY_LOW ->
                Log.w(TAG, "Heart-rate sensor accuracy: LOW")
            SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM ->
                Log.d(TAG, "Heart-rate sensor accuracy: MEDIUM")
            SensorManager.SENSOR_STATUS_ACCURACY_HIGH ->
                Log.d(TAG, "Heart-rate sensor accuracy: HIGH")
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode != REQUEST_CODE_PERMISSIONS) {
            return false
        }

        val granted = hasRequiredPermissions() ||
            (grantResults.isNotEmpty() && grantResults.any { it == PackageManager.PERMISSION_GRANTED })

        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
        return true
    }

    companion object {
        private const val TAG = "HeartRatePlugin"
        private const val REQUEST_CODE_PERMISSIONS = 2047
        private const val PERMISSION_READ_HEART_RATE = "android.permission.health.READ_HEART_RATE"
    }
}
