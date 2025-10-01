plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android") // usa el id moderno
    // El plugin de Flutter va DESPUÉS de Android y Kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.hook_deliveryprueba"

    // Forzamos las versiones requeridas por tus plugins
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.hook_deliveryprueba"
        minSdk = 23          // CameraX (mobile_scanner) exige >= 23
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
