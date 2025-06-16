# Keep the JP2Decoder class and everything in the package
-keep class com.gemalto.jp2.** { *; }
-dontwarn com.gemalto.jp2.**

# Keep all classes in PDFBox if you're using it
-keep class com.tom_roush.pdfbox.** { *; }
-dontwarn com.tom_roush.pdfbox.**

# Google Play Core library
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Keep all annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Exceptions

# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Additional rules to handle libraries
-keep class androidx.** { *; }
-keep class com.google.** { *; }

# Preserve all native method names and the names of their classes.
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep generic signatures
-keepattributes Signature

# We're not using kotlin reflection
-dontwarn kotlin.reflect.**

# Prevent R8 from stripping interface information from TypeAdapter, TypeAdapterFactory
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
