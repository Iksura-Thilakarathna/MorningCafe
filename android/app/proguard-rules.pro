# Flutter Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Sqflite
-keep class com.tekartik.sqflite.** { *; }

# Local Auth & AndroidX Biometrics
-keep class androidx.biometric.** { *; }
-keep class io.flutter.plugins.localauth.** { *; }

# Path Provider & Share Plus
-keep class dev.fluttercommunity.plus.share.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }

# Suppress warnings
-dontwarn io.flutter.**
-dontwarn com.tekartik.**
-dontwarn dev.fluttercommunity.**
