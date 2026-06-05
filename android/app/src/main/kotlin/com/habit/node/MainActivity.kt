package com.habit.node

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
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

    private var pendingAlarmPayload: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableLockScreenBypass" -> {
                    runOnUiThread { applyLockScreenBypass(enable = true) }
                    result.success(true)
                }
                "disableLockScreenBypass" -> {
                    runOnUiThread { applyLockScreenBypass(enable = false) }
                    result.success(true)
                }
                "isDeviceLocked" -> {
                    val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                    result.success(km.isKeyguardLocked)
                }
                "getAlarmPayload" -> {
                    val payload = pendingAlarmPayload
                    pendingAlarmPayload = null
                    result.success(payload)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // 🚀 MASTER FIX: অ্যালার্মের জন্য চালু হলে নেটিভ স্প্ল্যাশ স্ক্রিন সাথে সাথে গায়েব করে কালো করে দেবে!
        val launchedByAlarm = isLaunchedByAlarmNotification(intent)
        if (launchedByAlarm) {
            window.decorView.setBackgroundColor(Color.BLACK)
            window.setBackgroundDrawableResource(android.R.color.black)
        }

        super.onCreate(savedInstanceState)
        checkIntentForAlarm(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        checkIntentForAlarm(intent)
    }

    private fun checkIntentForAlarm(intent: Intent?) {
        val payload = intent?.getStringExtra("payload")
        if (payload != null && payload.startsWith("alarm:")) {
            pendingAlarmPayload = payload
            runOnUiThread {
                applyLockScreenBypass(enable = true)
            }
        }
    }

    private fun applyLockScreenBypass(enable: Boolean) {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager

        if (enable) {
            if (wakeLock == null) {
                @Suppress("DEPRECATION")
                wakeLock = pm.newWakeLock(
                    PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                    "HabitNode::AlarmWakeLock"
                )
            }
            if (wakeLock?.isHeld == false) {
                wakeLock?.acquire(10 * 60 * 1000L)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
            }
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        } else {
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

    private fun isLaunchedByAlarmNotification(intentToCheck: Intent?): Boolean {
        val currentIntent = intentToCheck ?: return false
        val payload = currentIntent.getStringExtra("payload") ?: ""
        val fromNotification = currentIntent.getBooleanExtra("from_alarm_notification", false)
        return fromNotification || payload.startsWith("alarm:")
    }
}