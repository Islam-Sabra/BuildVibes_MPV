import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The upload key lives outside the repo (never in git): by default in
// "BuildVibes keys" next to the project folder, or where BV_KEY_PROPERTIES
// points. See docs/release.md.
val uploadKey = Properties().apply {
    val path = System.getenv("BV_KEY_PROPERTIES")
        ?: rootProject.file("../../BuildVibes keys/key.properties").path
    val file = file(path)
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "com.buildvibes.buildvibes"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.buildvibes.buildvibes"
        // The version comes from pubspec.yaml (0.9.0+1: name and build number).
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (uploadKey.containsKey("storeFile")) {
            create("upload") {
                storeFile = file(uploadKey.getProperty("storeFile"))
                storePassword = uploadKey.getProperty("storePassword")
                keyAlias = uploadKey.getProperty("keyAlias")
                keyPassword = uploadKey.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Signed with the upload key only, never the debug key.
            signingConfig = signingConfigs.findByName("upload")
        }
    }
}

// Without the upload key a release build stops, instead of making an app
// that can't be installed over the store's. Debug builds don't need it.
gradle.taskGraph.whenReady {
    if (uploadKey.isEmpty && allTasks.any { it.name.contains("Release") }) {
        throw GradleException(
            "No upload key: put key.properties in \"BuildVibes keys\" next to the " +
                "project, or set BV_KEY_PROPERTIES (docs/release.md)."
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
