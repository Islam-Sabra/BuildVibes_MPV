package com.buildvibes.buildvibes

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Push (FCM) arrives on these channels, made at every start, before
        // this phone registers its push token; their names follow the
        // phone's language (values / values-ar). A push naming a channel
        // that doesn't exist yet (an older build) goes to the manifest's
        // default, "buildvibes".
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(
                NotificationChannel(
                    "buildvibes",
                    getString(R.string.push_channel_name),
                    NotificationManager.IMPORTANCE_HIGH,
                ),
            )
            // Review 89 M2: direct messages and Space chat (the push
            // function's MESSAGE_CHANNEL), with sound and vibration on
            // each message. A channel's sound and vibration are fixed once
            // made, hence a new id rather than changing "buildvibes".
            manager.createNotificationChannel(
                NotificationChannel(
                    "buildvibes_messages",
                    getString(R.string.push_messages_channel_name),
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply { enableVibration(true) },
            )
        }
    }

    // S4 "Open phone settings": this app's notification settings. F9 "Fix
    // it": this app's own page (Autostart and battery on Xiaomi phones),
    // and who made the phone.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "buildvibes/settings")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openNotificationSettings" -> {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        } else {
                            appDetails()
                        }
                        startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(null)
                    }
                    "openAppSettings" -> {
                        startActivity(appDetails().addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(null)
                    }
                    "phoneMakers" -> result.success(listOf(Build.MANUFACTURER, Build.BRAND))
                    // F102: opening a conversation takes its notification
                    // off the phone. FCM draws a notification message under
                    // its tag (the conversation's id) with id 0.
                    "cancelNotification" -> {
                        val tag = call.argument<String>("tag")
                        if (tag != null) {
                            getSystemService(NotificationManager::class.java).cancel(tag, 0)
                        }
                        result.success(null)
                    }
                    // F37: the phone's 24-hour setting, read again when the
                    // app comes back to the front (Android doesn't tell
                    // Flutter about a change until the app restarts).
                    "is24Hour" -> result.success(
                        android.text.format.DateFormat.is24HourFormat(this),
                    )
                    // F67: a tick, or the strong haptic for a check and a
                    // sign-off, as the phone's own effect.
                    "haptic" -> result.success(haptic(call.arguments as String))
                    // Settings → About: the installed version and build number
                    // (versionCode, the git commit count; docs/release.md).
                    "buildInfo" -> {
                        val info = packageManager.getPackageInfo(packageName, 0)
                        val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            info.longVersionCode
                        } else {
                            @Suppress("DEPRECATION")
                            info.versionCode.toLong()
                        }
                        result.success(mapOf("version" to info.versionName, "build" to code.toString()))
                    }
                    else -> result.notImplemented()
                }
            }
        // Review 114: the alerts setup. What the phone can confirm, and the
        // exact page for each line; the makers' pages come from the app
        // (alert_makers.dart), so this side holds no maker list.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "buildvibes/alerts")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(alertStatus())
                    "openAutostart", "openBattery" -> {
                        val pages = call.argument<List<Map<String, String>>>("pages").orEmpty()
                        result.success(if (openFirst(pages)) "maker" else openAppDetails())
                    }
                    "openChannel" -> {
                        val channel = call.argument<String>("channel")
                        result.success(openChannel(channel))
                    }
                    else -> result.notImplemented()
                }
            }
        // F5: the "sent" sound plays only when the ringer is on; silent
        // and vibrate get the haptic alone.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "buildvibes/sound")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ringerNormal" -> result.success(
                        getSystemService(AudioManager::class.java).ringerMode ==
                            AudioManager.RINGER_MODE_NORMAL,
                    )
                    else -> result.notImplemented()
                }
            }
        // Review 103: the phone's document scanner is Google's, part of
        // Google Play services; without them (Huawei and others) the app's
        // camera takes the pages.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "buildvibes/scan")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasDocumentScanner" -> result.success(
                        GoogleApiAvailability.getInstance()
                            .isGooglePlayServicesAvailable(this) == ConnectionResult.SUCCESS,
                    )
                    else -> result.notImplemented()
                }
            }
    }

    // True when played, false when the phone's Haptic feedback is off (its
    // choice wins), null when the phone has no such effect (Flutter's
    // impact plays instead).
    private fun haptic(kind: String): Boolean? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        if (Settings.System.getInt(
                contentResolver,
                Settings.System.HAPTIC_FEEDBACK_ENABLED,
                1,
            ) == 0
        ) {
            return false
        }
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(VibratorManager::class.java).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Vibrator::class.java)
        }
        if (vibrator == null || !vibrator.hasVibrator()) return null
        val effect = if (kind == "strong") {
            VibrationEffect.EFFECT_HEAVY_CLICK
        } else {
            VibrationEffect.EFFECT_TICK
        }
        vibrator.vibrate(VibrationEffect.createPredefined(effect))
        return true
    }

    // Review 114: the Need you now channel on at high importance or above
    // (null before Android 8, or before the channel is made), and battery
    // optimisation off for BuildVibes.
    private fun alertStatus(): Map<String, Boolean?> {
        val channel = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(NotificationManager::class.java)
                .getNotificationChannel("need_you")
                ?.let { it.importance >= NotificationManager.IMPORTANCE_HIGH }
        } else {
            null
        }
        val battery = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(packageName)
        } else {
            true
        }
        return mapOf("channel" to channel, "battery" to battery)
    }

    // The first maker page this phone has. Tried, not looked up first:
    // since Android 11 another app's activities are hidden from lookups
    // without a <queries> entry, but starting one still works. MIUI's
    // battery page reads this app's package and label from the extras.
    private fun openFirst(pages: List<Map<String, String>>): Boolean {
        for (page in pages) {
            val pkg = page["package"] ?: continue
            val activity = page["activity"] ?: continue
            val intent = Intent(page["action"] ?: Intent.ACTION_MAIN)
                .setComponent(ComponentName(pkg, activity))
                .putExtra("package_name", packageName)
                .putExtra("package_label", applicationInfo.loadLabel(packageManager).toString())
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                startActivity(intent)
                return true
            } catch (e: Exception) {
                // Not on this phone (ActivityNotFoundException), or closed
                // to other apps (SecurityException): the next one.
            }
        }
        return false
    }

    private fun openAppDetails(): String {
        startActivity(appDetails().addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        return "app"
    }

    // The app's notification settings on one channel (MIUI shows Floating
    // notifications there); the app's notification settings when the
    // channel page can't open.
    private fun openChannel(channel: String?): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && channel != null) {
            try {
                startActivity(
                    Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        .putExtra(Settings.EXTRA_CHANNEL_ID, channel)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
                return "channel"
            } catch (e: Exception) {
                // Below.
            }
        }
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        } else {
            appDetails()
        }
        startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        return "app"
    }

    private fun appDetails() = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
        .setData(android.net.Uri.fromParts("package", packageName, null))
}
