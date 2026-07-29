plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter Gradle Plugin mütləq Android və Kotlin pluginlərindən sonra gəlməlidir.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.aliyev_apk"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        // Core library desugaring-i aktiv edirik
        isCoreLibraryDesugaringEnabled = true

        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.aliyev_apk"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Real tətbiq üçün öz imza konfiqurasiyanızı (signingConfig) əlavə edin.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ƏSAS HİSSƏ: Xətanı aradan qaldıran kitabxana budur
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}