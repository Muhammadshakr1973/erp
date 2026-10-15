# Flutter ProGuard / R8 Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.**  { *; }

# Flutter Play Store Deferred Components (Play Core)
-dontwarn com.google.android.play.core.**

# SLF4J (used by pusher_channels_flutter / pusher-java-client)
-dontwarn org.slf4j.**
-keep class org.slf4j.** { *; }

# Pusher Client
-dontwarn com.pusher.**
-keep class com.pusher.** { *; }

# OkHttp & Okio
-dontwarn okhttp3.**
-dontwarn okio.**

# Suppress annotations and optional dependencies warnings
-dontwarn javax.annotation.**
-dontwarn javax.annotation.concurrent.**
