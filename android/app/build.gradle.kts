plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.hardstone.ia_music"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.hardstone.ia_music"
        // 最低 OS 版本（DEC-008 ④ 锁定：Android 8+ = API 26）
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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

dependencies {
    // T9A（S6 Android 侧）：DEC-008① 锁定的 MIT yt-dlp AAR（内嵌 CPython 3.13+yt-dlp）
    // + MIT ffmpeg-kit（-x/--audio-format mp3 后处理所需；经 --ffmpeg-location 供路径）。
    implementation("dev.ffmpegkit-maintained:yt-dlp-android:2.0.2")
    implementation("dev.ffmpegkit-maintained:ffmpeg-kit-full:8.1.7")
    // ffmpeg-kit 运行时必需（POM 未声明：LLGPL fork 打包缺依赖——T9A 实证
    // NoClassDefFoundError com/arthenica/smartexception/java/Exceptions）。
    implementation("com.arthenica:smart-exception-java:0.2.1")
}
