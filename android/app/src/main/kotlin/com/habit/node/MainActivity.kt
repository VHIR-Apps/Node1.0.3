package com.habit.node

import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.habit.node/lock_screen"

    // Track whether alarm bypass was requested
    // before onCreate completed
    private var pendingBypassEnable = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {

                // Alarm screen opening — enable lock screen bypass
                "enableLockScreenBypass" -> {
                    runOnUiThread {
                        applyLockScreenBypass(enable = true)
                    }
                    result.success(true)
                }

                // Alarm screen closed — disable lock screen bypass
                "disableLockScreenBypass" -> {
                    runOnUiThread {
                        applyLockScreenBypass(enable = false)
                        pendingBypassEnable = false
                    }
                    result.success(true)
                }

                // Check if device is currently locked
                "isDeviceLocked" -> {
                    val km = getSystemService(
                        Context.KEYGUARD_SERVICE
                    ) as KeyguardManager
                    val locked = km.isKeyguardLocked
                    result.success(locked)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Check if this activity was launched by
        // a full-screen alarm notification
        val launchedByAlarm = isLaunchedByAlarmNotification()

        if (launchedByAlarm) {
            // Alarm notification launched this activity
            // — enable bypass immediately before Flutter loads
            applyLockScreenBypass(enable = true)
            pendingBypassEnable = true
        } else {
            // Normal app launch — keep lock screen secure
            applyLockScreenBypass(enable = false)
            pendingBypassEnable = false
        }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        // Activity already running — check if alarm notification
        // brought us here
        val launchedByAlarm = isLaunchedByAlarmNotification()
        if (launchedByAlarm) {
            runOnUiThread {
                applyLockScreenBypass(enable = true)
                pendingBypassEnable = true
            }
        }
    }

    // Apply or remove lock screen bypass flags
    private fun applyLockScreenBypass(enable: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            // API 27+ — use modern methods
            setShowWhenLocked(enable)
            setTurnScreenOn(enable)
        } else {
            // API < 27 — use window flags
            @Suppress("DEPRECATION")
            if (enable) {
                window.addFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
                )
            } else {
                window.clearFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
                )
            }
        }
    }

    // Check if current intent came from an alarm notification
    private fun isLaunchedByAlarmNotification(): Boolean {
        val intent = intent ?: return false
        val payload = intent.getStringExtra("payload") ?: ""
        val fromNotification = intent.getBooleanExtra(
            "from_alarm_notification", false
        )
        return fromNotification || payload.startsWith("alarm:")
    }
}