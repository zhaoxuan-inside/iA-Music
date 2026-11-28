plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.hardstone.iamusic"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.hardstone.iamusic"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
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

    // Universal APK: arm64-v8a + x86_64（模拟器/全设备统一验证）。
    // 推理模型不随包分发：在线下载 + data 层 ModelStore 管理
    // （见 native/PROVENANCE.md；模型加载走普通文件 mmap，无资产压缩问题）。
}

dependencies {
    // LiteRT（原 TensorFlow Lite）：音频嵌入向量推理（ia_music/embedding 通道；
    // 模型工件与哈希见 native/PROVENANCE.md）。
    implementation("com.google.ai.edge.litert:litert:2.3.0")
    // Room 2.6.1 强制对齐：传递依赖 room-runtime 2.5.0 的 R8 full-mode 规则
    // 有缺陷（WorkDatabase _Impl 反射实例化失败）——Android 15 上 release
    // 包启动即崩（androidx.startup InitializerProvider 阶段）。2.6.0+ 自带
    // 正确的 keep 规则。模拟器（API 35）实测捕获。
    implementation("androidx.room:room-runtime:2.6.1")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
