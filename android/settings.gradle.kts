try {
    val pe = Class.forName("java.lang.ProcessEnvironment")
    val theEnvironmentField = pe.getDeclaredField("theEnvironment")
    theEnvironmentField.isAccessible = true
    val env = theEnvironmentField.get(null) as MutableMap<String, String>
    env.remove("ANDROID_PREFS_ROOT")
    env.remove("ANDROID_SDK_HOME")

    val theCaseInsensitiveEnvironmentField = pe.getDeclaredField("theCaseInsensitiveEnvironment")
    theCaseInsensitiveEnvironmentField.isAccessible = true
    val ciEnv = theCaseInsensitiveEnvironmentField.get(null) as MutableMap<String, String>
    ciEnv.remove("ANDROID_PREFS_ROOT")
    ciEnv.remove("ANDROID_SDK_HOME")
} catch (e: Throwable) {
    // Ignore
}

pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
