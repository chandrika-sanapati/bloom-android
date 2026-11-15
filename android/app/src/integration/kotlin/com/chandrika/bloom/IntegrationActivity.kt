package com.chandrika.bloom

import android.app.ActivityOptions
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Compiled only with bloomIntegrationTest=true; absent from normal APKs.
private fun tapOwnNotification(context: Context, id: Int): Boolean {
    val manager = context.getSystemService(NotificationManager::class.java)
    val notification = manager.activeNotifications.firstOrNull { it.id == id } ?: return false
    val options = ActivityOptions.makeBasic()
    if (Build.VERSION.SDK_INT >= 34) {
        options.setPendingIntentBackgroundActivityStartMode(
            ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
        )
    }
    notification.notification.contentIntent.send(context, 0, null, null, null, null, options.toBundle())
    return true
}

class IntegrationActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bloom.integration/notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "tapNotification" -> result.success(tapOwnNotification(this, call.argument<Int>("id")!!))
                    "pressBack" -> {
                        onBackPressed()
                        result.success(null)
                    }
                    "backgroundApp" -> result.success(moveTaskToBack(true))
                    else -> result.notImplemented()
                }
            }
    }
}
