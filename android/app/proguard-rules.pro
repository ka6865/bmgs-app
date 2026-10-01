# Flutter / Dart
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core(deferred components)는 이 앱에서 사용하지 않는다.
# Flutter embedding이 참조만 하므로 R8 missing class 경고를 무시한다.
-dontwarn com.google.android.play.core.**

# Supabase / OkHttp 계열이 사용하는 reflection 경고 억제
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**
