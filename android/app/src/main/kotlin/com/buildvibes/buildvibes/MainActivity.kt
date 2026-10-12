package com.buildvibes.buildvibes

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Push (FCM) arrives on this channel; its name follows the phone's
        // language (values / values-ar).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "buildvibes",
                getString(R.string.push_channel_name),
                NotificationManager.IMPORTANCE_HIGH,
            )
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    // S4 "Open phone settings": this app's notification settings.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "buildvibes/settings")
            .setMethodCallHandler { call, result ->
                if (call.method == "openNotificationSettings") {
                    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    } else {
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            .setData(android.net.Uri.fromParts("package", packageName, null))
                    }
                    startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
