package com.habit.node

import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.habit.node/lock_screen"

    private var pendingBypassEnable = false
    private var wakeLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {

                "enableLockScreenBypass" -> {
                    runOnUiThread {
                        applyLockScreenBypass(enable = true)
                    }
                    result.success(true)
                }

                "disableLockScreenBypass" -> {
                    runOnUiThread {
                        applyLockScreenBypass(enable = false)
                        pendingBypassEnable = false
                    }
                    result.success(true)
                }

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

        val launchedByAlarm = isLaunchedByAlarmNotification()

        if (launchedByAlarm) {
            applyLockScreenBypass(enable = true)
            pendingBypassEnable = true
        } else {
            applyLockScreenBypass(enable = false)
            pendingBypassEnable = false
        }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val launchedByAlarm = isLaunchedByAlarmNotification()
        if (launchedByAlarm) {
            runOnUiThread {
                applyLockScreenBypass(enable = true)
                pendingBypassEnable = true
            }
        }
    }

    // 🚀 SECURE FIX: Lockscreen Overlay (Without Unlocking)
    private fun applyLockScreenBypass(enable: Boolean) {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager

        if (enable) {
            // 1. Force Screen On
            if (wakeLock == null) {
                @Suppress("DEPRECATION")
                wakeLock = pm.newWakeLock(
                    PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                    "HabitNode::AlarmWakeLock"
                )
            }
            if (wakeLock?.isHeld == false) {
                wakeLock?.acquire(10 * 60 * 1000L) // 10 minutes max
            }

            // 2. Show Over Lock Screen (WITHOUT Unlocking Keyguard)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
                // ❌ REMOVED: requestDismissKeyguard (এটিই প্যাটার্ন বা পিন চাইতো!)
            }
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                // ❌ REMOVED: FLAG_DISMISS_KEYGUARD (লক স্ক্রিন রিমুভ করার কমান্ড বাতিল)
            )
        } else {
            // Release Screen
            wakeLock?.let {
                if (it.isHeld) it.release()
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(false)
                setTurnScreenOn(false)
            }
            @Suppress("DEPRECATION")
            window.clearFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }

    private fun isLaunchedByAlarmNotification(): Boolean {
        val intent = intent ?: return false
        val payload = intent.getStringExtra("payload") ?: ""
        val fromNotification = intent.getBooleanExtra(
            "from_alarm_notification", false
        )
        return fromNotification || payload.startsWith("alarm:")
    }
}