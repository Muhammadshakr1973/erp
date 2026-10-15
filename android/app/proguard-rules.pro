# Flutter ProGuard / R8 Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.**  { *; }

# SLF4J (used by pusher_channels_flutter / pusher-java-client)
-dontwarn org.slf4j.**
-keep class org.slf4j.** { *; }

# Pusher Client
-dontwarn com.pusher.**
-keep class com.pusher.** { *; }

# Suppress annotations and optional dependencies warnings
-dontwarn javax.annotation.**
-dontwarn javax.annotation.concurrent.**
