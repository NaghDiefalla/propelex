// ====================================================================
// 1. KOTLIN IMPORTS AND KEYSTORE PROPERTIES READER
// PATH CORRECTION: The path now correctly points to the 'key.properties' 
// file inside the current (app) directory.
// ====================================================================
import java.util.Properties
import java.io.FileInputStream

// The path is corrected to look inside the android/app/ directory
val keystoreProperties = Properties()
val keystorePropertiesFile = file("key.properties") // Looks in the current directory (android/app/)

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
// ====================================================================


plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.newdawnstudio.propelex"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // ====================================================================
    // 2. SIGNING CONFIGURATION (Kotlin DSL)
    // This creates the "release" signing config using the loaded properties.
    // ====================================================================
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            // The storeFile path uses 'file()' which looks for the file relative to this script
            storeFile = file(keystoreProperties.getProperty("storeFile") ?: "")
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }
    // ====================================================================


    defaultConfig {
        applicationId = "com.newdawnstudio.propelex"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") { // Use getByName("release") in Kotlin DSL
            // Link to the new, secure release signing configuration
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
dependencies {
    // باقي الـ dependencies هنا
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}