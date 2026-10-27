# Flutter Proguard Rules for Google Sign In & Firebase Auth

# Keep Google Play Services and Sign In
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.api.** { *; }
-keep class com.google.android.gms.tasks.** { *; }

# Keep Firebase Auth
-keep class com.google.firebase.** { *; }
-keep class com.google.firebase.auth.** { *; }

# Keep annotations and signatures for reflection
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Prevent obfuscation of serializable fields used by OAuth
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# MediaKit & libmpv ProGuard Rules (Required for Android Release Mode)
-keep class com.alexmercerind.** { *; }
-keep interface com.alexmercerind.** { *; }
-keepclasseswithmembers class * {
    native <methods>;
}

