package com.closerapp.closer

import android.app.NotificationChannel
import android.app.NotificationManager
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.os.Build
import android.os.Bundle
import com.closerapp.closer.widget.CloserWidgetProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.closerapp.closer/widgets")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Redraws only widgets showing this group (or all when null).
                    "refresh" -> {
                        CloserWidgetProvider.refresh(this, call.argument<String>("groupId"))
                        result.success(null)
                    }
                    // Asks the launcher to add a widget (Android 8+).
                    "requestPin" -> {
                        val manager = getSystemService(AppWidgetManager::class.java)
                        val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                            manager.isRequestPinAppWidgetSupported
                        if (supported) {
                            manager.requestPinAppWidget(
                                ComponentName(this, CloserWidgetProvider::class.java),
                                null,
                                null,
                            )
                        }
                        result.success(supported)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Channel used by push notifications (matches dispatch-push). High
     * importance so new moments pop up; people can lower it in system settings.
     * A channel's importance can't change after creation, hence the new id.
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.deleteNotificationChannel("closer_activity") // pre-launch channel
        val channel = NotificationChannel(
            "closer_moments",
            getString(R.string.notification_channel_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply { description = getString(R.string.notification_channel_description) }
        manager.createNotificationChannel(channel)
    }
}
