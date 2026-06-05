package com.habit.node

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.view.KeyEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.habit.node/lock_screen"
    private val ALARM_CHANNEL = "com.habit.node/alarm_trigger"

    private var wakeLock: PowerManager.WakeLock? = null
    private var pendingAlarmPayload: String? = null
    private var alarmMethodChannel: MethodChannel? = null

    // 🔒 SECURITY: Alarm mode flag
    private var isAlarmModeActive = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enableLockScreenBypass" -> {
                        runOnUiThread {
                            isAlarmModeActive = true
                            applyLockScreenBypass(enable = true)
                        }
                        result.success(true)
                    }
                    "disableLockScreenBypass" -> {
                        runOnUiThread {
                            isAlarmModeActive = false
                            applyLockScreenBypass(enable = false)
                        }
                        result.success(true)
                    }
                    "isDeviceLocked" -> {
                        val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                        result.success(km.isKeyguardLocked)
                    }
                    "getAlarmPayload" -> {
                        val payload = pendingAlarmPayload
                        result.success(payload)
                    }
                    "clearAlarmPayload" -> {
                        pendingAlarmPayload = null
                        result.success(true)
                    }
                    "isAlarmActive" -> {
                        result.success(isAlarmModeActive)
                    }
                    else -> result.notImplemented()
                }
            }

        alarmMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ALARM_CHANNEL
        )

        pendingAlarmPayload?.let { payload ->
            if (payload.startsWith("alarm:")) {
                val habitId = payload.removePrefix("alarm:")
                runOnUiThread {
                    alarmMethodChannel?.invokeMethod("openAlarmScreen", habitId)
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        val launchedByAlarm = isLaunchedByAlarmNotification(intent)
        if (launchedByAlarm) {
            window.decorView.setBackgroundColor(Color.BLACK)
            window.setBackgroundDrawableResource(android.R.color.black)
            isAlarmModeActive = true
            applyLockScreenBypass(enable = true)
        }

        super.onCreate(savedInstanceState)
        checkIntentForAlarm(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        checkIntentForAlarm(intent)
    }

    override fun onResume() {
        super.onResume()
        pendingAlarmPayload?.let { payload ->
            if (payload.startsWith("alarm:")) {
                val habitId = payload.removePrefix("alarm:")
                runOnUiThread {
                    alarmMethodChannel?.invokeMethod("openAlarmScreen", habitId)
                }
            }
        }

        // 🔒 SECURITY: Alarm mode এ থাকলে আবার lock bypass enable করো
        if (isAlarmModeActive) {
            applyLockScreenBypass(enable = true)
        }
    }

    // 🔒 SECURITY: User Home / Recent button press করলে alarm এ ফিরিয়ে আনো
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (isAlarmModeActive) {
            // Alarm চলাকালীন home press করলে activity শেষ করো
            // notification থেকে আবার alarm আসবে
            android.util.Log.d("HabitNode", "🔒 Home press during alarm — minimizing")
        }
    }

    // 🔒 SECURITY: Hardware key intercept
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (isAlarmModeActive) {
            when (keyCode) {
                KeyEvent.KEYCODE_BACK -> {
                    android.util.Log.d("HabitNode", "🔒 Back key blocked during alarm")
                    return true // ✅ Block back
                }
                KeyEvent.KEYCODE_MENU -> {
                    return true // ✅ Block menu
                }
                // Volume keys allowed — user wants to control volume
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    // 🔒 SECURITY: Window focus loss handling
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (isAlarmModeActive && hasFocus) {
            // Focus ফিরে এলে আবার lock screen flags set করো
            applyLockScreenBypass(enable = true)
        }
    }

    private fun checkIntentForAlarm(intent: Intent?) {
        val payload = intent?.getStringExtra("payload")
        if (payload != null && payload.startsWith("alarm:")) {
            pendingAlarmPayload = payload
            isAlarmModeActive = true
            runOnUiThread {
                applyLockScreenBypass(enable = true)
                val habitId = payload.removePrefix("alarm:")
                alarmMethodChannel?.invokeMethod("openAlarmScreen", habitId)
            }
        }
    }

    private fun applyLockScreenBypass(enable: Boolean) {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager

        if (enable) {
            if (wakeLock == null) {
                @Suppress("DEPRECATION")
                wakeLock = pm.newWakeLock(
                    PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                            PowerManager.ACQUIRE_CAUSES_WAKEUP or
                            PowerManager.ON_AFTER_RELEASE,
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
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )

            // 🔒 SECURITY: Window secure flag — screenshot block করে
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE
            )
        } else {
            wakeLock?.let { if (it.isHeld) it.release() }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(false)
                setTurnScreenOn(false)
            }
            @Suppress("DEPRECATION")
            window.clearFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                        WindowManager.LayoutParams.FLAG_SECURE
            )
        }
    }

    private fun isLaunchedByAlarmNotification(intentToCheck: Intent?): Boolean {
        val currentIntent = intentToCheck ?: return false
        val payload = currentIntent.getStringExtra("payload") ?: ""
        return payload.startsWith("alarm:")
    }
}