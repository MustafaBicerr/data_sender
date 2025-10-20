plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.data_sender"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.data_sender"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

     buildTypes {
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
            // debug imzası zaten otomatik
        }
        getByName("release") {
            // GEÇİCİ: shrink kapalı (APK büyük olur ama derleme kolaylaşır)
            isMinifyEnabled = false
            isShrinkResources = false

            // GEÇİCİ: release’i debug imzasıyla imzala (sadece cihazda test)
            signingConfig = signingConfigs.getByName("debug")
        }
    }

     lint {
        // Release'te lint'i çalıştırma
        checkReleaseBuilds = false
        abortOnError = false
        disable += setOf("LintVitalRelease") // kritik lint görevini de kapat
    }
}

flutter {
    source = "../.."
}
