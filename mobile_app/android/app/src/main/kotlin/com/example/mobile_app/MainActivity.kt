package com.example.mobile_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.mobile_app/sound"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "playEmergencySound") {
                playEmergencySound()
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        // Create notification channel BEFORE super.onCreate() to ensure it exists early
        // This is critical for OneSignal to find the channel
        createNotificationChannel()
        super.onCreate(savedInstanceState)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "emergency_alerts"
            val channelName = "Emergency Alerts"
            val description = "Emergency notifications with custom sound"
            val importance = NotificationManager.IMPORTANCE_HIGH
            
            // Get the resource ID for the emergency_alert sound file
            val soundResourceId = resources.getIdentifier("emergency_alert", "raw", packageName)
            
            // Create custom sound URI from raw resource
            // Format: android.resource://package_name/resource_id
            val soundUri = if (soundResourceId != 0) {
                // Use the correct format for Android resource URI
                Uri.parse("android.resource://${packageName}/raw/emergency_alert")
            } else {
                // Fallback to default notification sound if custom sound not found
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            }
            
            // Configure audio attributes for the sound
            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .build()
            
            val channel = NotificationChannel(channelId, channelName, importance).apply {
                this.description = description
                this.enableLights(true)
                this.enableVibration(true)
                this.setSound(soundUri, audioAttributes)
                this.setShowBadge(true)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun playEmergencySound() {
        try {
            val soundResourceId = resources.getIdentifier("emergency_alert", "raw", packageName)
            if (soundResourceId != 0) {
                val mediaPlayer = MediaPlayer.create(this, soundResourceId)
                mediaPlayer?.setOnCompletionListener { it.release() }
                mediaPlayer?.start()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
