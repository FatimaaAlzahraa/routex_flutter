plugins {
    id("com.android.application")
    id("kotlin-android")
    // لازم يبقى بعد Android/Kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.routex"

    // ارفعي الـ compileSdk لأعلى نسخة مطلوبة (36)
    compileSdk = 36

    // لو عندك block compileOptions/kotlinOptions سيبيه زي ما هو
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.routex"
        minSdk = flutter.minSdkVersion
        // يفضل ترفعي targetSdk برضه لـ 36 (اختياري بس مفضل)
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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
