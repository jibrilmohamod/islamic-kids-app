package com.jibrilmohamod.islamic_kids_app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// AudioServiceActivity shares the Flutter engine with the media service, so
// recitation keeps playing when the activity goes away (ADR 0002).
//
// The "app/notifications" channel asks for Android 13's notification
// permission and opens the app's notification settings. It replaces the
// permission_handler plugin, whose current version needs a newer Android
// SDK than our Gradle plugin supports.
class MainActivity : AudioServiceActivity() {
    private var pending: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app/notifications").setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(allowed())
                "request" -> request(result)
                "openSettings" -> {
                    val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    startActivity(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun allowed(): Boolean {
        val enabled = NotificationManagerCompat.from(this).areNotificationsEnabled()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return enabled
        return enabled && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
    }

    private fun request(result: MethodChannel.Result) {
        if (allowed() || Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(allowed())
            return
        }
        if (pending != null) {
            result.success(false)
            return
        }
        pending = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_CODE) return
        pending?.success(allowed())
        pending = null
    }

    private companion object {
        const val REQUEST_CODE = 7301
    }
}
