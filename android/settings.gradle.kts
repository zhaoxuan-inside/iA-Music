pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

dependencyResolutionManagement {
    // PREFER_PROJECT：插件工程自声明的仓库优先（file_picker 等），
    // settings 仓库兜底补 LiteRT（com.google.ai.edge.litert）的坐标解析。
    repositoriesMode = RepositoriesMode.PREFER_PROJECT
    repositories {
        google()
        mavenCentral()
    }
}

include(":app")
