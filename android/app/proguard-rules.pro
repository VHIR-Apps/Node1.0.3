# android/app/proguard-rules.pro

# Flutter-specific rules.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# 🛑 ═════════════════════════════════════════════════════════════════════
# 🛑 RULES FOR flutter_local_notifications (Fixes R8 Crash)
# 🛑 ═════════════════════════════════════════════════════════════════════
# This rule is critical to prevent a crash when the app is built in release mode.
# The plugin uses Gson and TypeToken to deserialize scheduled notifications from
# SharedPreferences. R8/ProGuard strips necessary generic type information,
# causing a `java.lang.IllegalStateException: TypeToken must be created with a type argument`.
# These rules preserve the required classes and their members.

-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.styles.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.channels.** { *; }

# ═════════════════════════════════════════════════════════════════════
# GSON rules (Dependency of flutter_local_notifications)
# ═════════════════════════════════════════════════════════════════════
# This ensures that Gson can correctly serialize and deserialize objects.
-keep class com.google.gson.Gson
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken
-keepattributes Signature
-keepattributes *Annotation*

# ═════════════════════════════════════════════════════════════════════
# General rules for common Firebase libraries
# ═════════════════════════════════════════════════════════════════════
-keep class com.google.firebase.** { *; }
-keepattributes Signature
-keepnames class com.google.android.gms.tasks.** { *; }

# Preserve custom model classes if they are serialized/deserialized
# by Firebase or other reflection-based libraries.
# Example: -keep class com.habit.node.models.** { *; }

# ═════════════════════════════════════════════════════════════════════
# Rules for common AndroidX libraries
# ═════════════════════════════════════════════════════════════════════
-dontwarn androidx.lifecycle.**
-dontwarn androidx.core.**
-dontwarn androidx.appcompat.**