plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
    // Le plugin Flutter doit être appliqué après Android et Kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.service_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.example.service_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        // Java 17 pour ton projet
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // ✅ Activer le core library desugaring pour Flutter Local Notifications
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        release {
            // Signature debug temporaire (ok pour tests)
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Firebase BoM (gère automatiquement les versions)
    implementation(platform("com.google.firebase:firebase-bom:34.8.0"))

    // Firebase Analytics
    implementation("com.google.firebase:firebase-analytics")

    implementation("com.google.firebase:firebase-messaging")
    // ✅ Dépendance nécessaire pour le desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")

}
