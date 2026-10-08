# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Uncomment this to preserve the line number information for
# debugging stack traces.
#-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile

# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.embedding.android.** { *; }

# Keep native methods
-keepclassmembers class * {
    native <methods>;
}

# Keep 16KB page size support
-keep class * extends android.app.Application
-keepattributes *Annotation*

# Ignore warnings about missing Play Core classes (they're optional and deprecated)
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Material Design
-keep class com.google.android.material.** { *; }
-dontwarn com.google.android.material.**

# AndroidX
-keep class androidx.** { *; }
-dontwarn androidx.**

# Multidex
-keep class androidx.multidex.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.**

# Keep Firebase classes
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Keep Google Play Services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# OneSignal
-keep class com.onesignal.** { *; }
-dontwarn com.onesignal.**

# Camera and Media
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# Keep Parcelable implementations
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# Keep Serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# General optimizations
-optimizationpasses 5
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-verbose