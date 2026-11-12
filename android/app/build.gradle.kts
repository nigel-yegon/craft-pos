import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    // id("kotlin-android") is REMOVED. AGP 9 has built-in Kotlin support.
    // The Flutter Gradle Plugin must be applied after the Android plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.craftpos.craft_pos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    // REMOVED: kotlinOptions block (no longer supported in AGP 9)

    defaultConfig {
        applicationId = "com.craftpos.craft_pos"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// NEW: Top-level Kotlin configuration using the new compilerOptions DSL
kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_11
    }
}

flutter {
    source = "../.."
}