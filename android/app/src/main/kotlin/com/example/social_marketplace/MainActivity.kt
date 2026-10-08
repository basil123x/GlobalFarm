package com.global.farm

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentResolver
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    companion object {
        const val CROWING_CHANNEL_ID = "globalfarm_crowing_v2"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createCrowingNotificationChannel()
    }

    private fun createCrowingNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val soundUri = Uri.parse(
            "${ContentResolver.SCHEME_ANDROID_RESOURCE}://$packageName/raw/crowing",
        )
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val channel = NotificationChannel(
            CROWING_CHANNEL_ID,
            "GlobalFarm Alerts",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Custom crowing sound for GlobalFarm push notifications"
            setSound(soundUri, audioAttributes)
            enableVibration(true)
            enableLights(true)
        }

        val manager = getSystemService(NotificationManager::class.java)
        manager?.createNotificationChannel(channel)
    }
}
