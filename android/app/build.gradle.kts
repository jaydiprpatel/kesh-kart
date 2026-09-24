import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

fun signingValue(propertyName: String, environmentName: String): String? =
    keystoreProperties.getProperty(propertyName)?.trim()?.takeIf { it.isNotEmpty() }
        ?: System.getenv(environmentName)?.trim()?.takeIf { it.isNotEmpty() }

val releaseKeyAlias = signingValue("keyAlias", "KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "KEY_PASSWORD")
val releaseStorePassword = signingValue("storePassword", "STORE_PASSWORD")
val releaseStoreFile = signingValue("storeFile", "STORE_FILE")?.let { rootProject.file(it) }
val releaseSigningConfigured =
    !releaseKeyAlias.isNullOrBlank() &&
        !releaseKeyPassword.isNullOrBlank() &&
        !releaseStorePassword.isNullOrBlank() &&
        releaseStoreFile?.isFile == true
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

android {
    namespace = "com.keshkart.barber"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.keshkart.barber"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (releaseSigningConfigured) {
                storeFile = requireNotNull(releaseStoreFile)
                keyAlias = requireNotNull(releaseKeyAlias)
                keyPassword = requireNotNull(releaseKeyPassword)
                storePassword = requireNotNull(releaseStorePassword)
            }
        }
    }

    buildTypes {
        release {
            val releaseConfig = signingConfigs.getByName("release")
            if (releaseBuildRequested && !releaseSigningConfigured) {
                throw GradleException(
                    "Release signing is not configured. Create android/key.properties from android/key.properties.example or provide KEY_* environment variables.",
                )
            }
            signingConfig = if (releaseSigningConfigured) releaseConfig else signingConfigs.getByName("debug")
        }
    }
    ndkVersion = "28.2.13676358"
}

flutter {
    source = "../.."
}

configurations.all {
    resolutionStrategy {
        force("com.google.mlkit:barcode-scanning:17.3.0")
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
