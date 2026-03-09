package com.example.elderlink

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Heart Rate Plugin for Wear OS
 * 
 * Automatically detects heart-rate sensor availability and provides:
 * - Real sensor data when available
 * - Mock data fallback when sensor is not available
 * 
 * Developer Verification:
 * To check if heart-rate sensor exists on device, run:
 * adb shell dumpsys sensorservice | grep -i heart
 */
class HeartRatePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler, SensorEventListener {
    private lateinit var context: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    
    private var sensorManager: SensorManager? = null
    private var heartRateSensor: Sensor? = null
    private var isSensorAvailable = false
    private var isMonitoring = false
    
    // Mock data generation
    private var mockHeartRate = 72
    private val random = java.util.Random()
    private var mockHandler: android.os.Handler? = null
    private var mockRunnable: Runnable? = null
    
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        
        // Check for heart-rate sensor
        heartRateSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_HEART_RATE)
        isSensorAvailable = heartRateSensor != null
        
        if (isSensorAvailable) {
            Log.d(TAG, "Heart rate sensor detected — using real data")
        } else {
            Log.d(TAG, "Heart rate sensor NOT available — using mock data")
        }
        
        // Setup method channel
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "heart_rate/methods")
        methodChannel.setMethodCallHandler(this)
        
        // Setup event channel for streaming heart rate data
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "heart_rate/stream")
        eventChannel.setStreamHandler(this)
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopMonitoring()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkSensor" -> {
                result.success(isSensorAvailable)
            }
            "startMonitoring" -> {
                startMonitoring()
                result.success(true)
            }
            "stopMonitoring" -> {
                stopMonitoring()
                result.success(true)
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        startMonitoring()
    }
    
    override fun onCancel(arguments: Any?) {
        stopMonitoring()
        eventSink = null
    }
    
    private fun startMonitoring() {
        if (isMonitoring) return
        
        isMonitoring = true
        
        if (isSensorAvailable && heartRateSensor != null) {
            // Use real sensor
            val success = sensorManager?.registerListener(
                this,
                heartRateSensor,
                SensorManager.SENSOR_DELAY_NORMAL
            ) ?: false
            
            if (!success) {
                Log.e(TAG, "Failed to register heart-rate sensor listener")
                isSensorAvailable = false
                startMockMonitoring()
            }
        } else {
            // Use mock data
            startMockMonitoring()
        }
    }
    
    private fun stopMonitoring() {
        if (!isMonitoring) return
        
        isMonitoring = false
        
        if (isSensorAvailable) {
            sensorManager?.unregisterListener(this)
        } else {
            // Stop mock monitoring
            mockRunnable?.let { mockHandler?.removeCallbacks(it) }
            mockHandler = null
            mockRunnable = null
        }
    }
    
    private fun startMockMonitoring() {
        // Generate initial mock heart rate (40-130 bpm)
        mockHeartRate = 60 + random.nextInt(70)
        
        mockHandler = android.os.Handler(android.os.Looper.getMainLooper())
        mockRunnable = object : Runnable {
            override fun run() {
                if (isMonitoring && eventSink != null) {
                    // Generate realistic variation (±5 bpm)
                    val variation = random.nextInt(11) - 5 // -5 to +5
                    mockHeartRate = (mockHeartRate + variation).coerceIn(40, 130)
                    
                    eventSink?.success(mockHeartRate)
                    
                    // Check for abnormal values
                    if (mockHeartRate < 50 || mockHeartRate > 110) {
                        Log.w(TAG, "Mock abnormal heart rate detected: $mockHeartRate bpm")
                    }
                    
                    // Schedule next update
                    mockHandler?.postDelayed(this, 3000)
                }
            }
        }
        
        // Start first update after 3 seconds
        mockHandler?.postDelayed(mockRunnable!!, 3000)
    }
    
    // SensorEventListener implementation
    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type == Sensor.TYPE_HEART_RATE && event.values.isNotEmpty()) {
            val heartRate = event.values[0].toInt()
            
            // Only send valid heart rate values (0 means no reading yet)
            if (heartRate > 0) {
                eventSink?.success(heartRate)
                
                // Check for abnormal values
                if (heartRate < 50 || heartRate > 110) {
                    Log.w(TAG, "Abnormal heart rate detected: $heartRate bpm")
                }
            }
        }
    }
    
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        when (accuracy) {
            SensorManager.SENSOR_STATUS_UNRELIABLE -> {
                Log.w(TAG, "Heart rate sensor accuracy: UNRELIABLE")
            }
            SensorManager.SENSOR_STATUS_ACCURACY_LOW -> {
                Log.w(TAG, "Heart rate sensor accuracy: LOW")
            }
            SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM -> {
                Log.d(TAG, "Heart rate sensor accuracy: MEDIUM")
            }
            SensorManager.SENSOR_STATUS_ACCURACY_HIGH -> {
                Log.d(TAG, "Heart rate sensor accuracy: HIGH")
            }
        }
    }
    
    companion object {
        private const val TAG = "HeartRatePlugin"
    }
}
