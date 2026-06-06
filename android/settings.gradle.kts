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
	        maven { url = uri("https://maven.aliyun.com/repository/google") }
	        maven { url = uri("https://maven.aliyun.com/repository/public") }
	        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
	        google()
	        mavenCentral()
	    }
	}
	plugins {
	    // 保持不变
	    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
	    // 【修改点 1】将 AGP 版本从 9.0.1 降低到 8.11.1 (推荐)
    id("com.android.application") version "8.11.1" apply false
    // 【修改点 2】将 Kotlin 版本调整为与 AGP 8.11 兼容的 2.2.20
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
	}
	include(":app")