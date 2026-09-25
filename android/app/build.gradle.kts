plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ling.pcv"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.ling.pcv"
        minSdk = maxOf(flutter.minSdkVersion, 24) // flutter_inappwebview 要求 minSdk >= 19；取 24 对齐生态
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // PCV 独立签名（与 LINGOS App 分离——独立产品）
    signingConfigs {
        create("release") {
            storeFile = file("../../pcv-release.jks")
            storePassword = "pcv2026"
            keyAlias = "pcv"
            keyPassword = "pcv2026"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
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
