package com.keshkart.barber

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            "appointment_updates",
            "KeshKart updates",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Booking, shop approval, and important KeshKart updates"
        }
        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }
}
