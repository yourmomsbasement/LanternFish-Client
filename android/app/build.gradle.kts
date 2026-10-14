import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

// The client version is shared by every platform and lives in the repository's package.json
val clientVersion: String = Regex("\"version\"\\s*:\\s*\"([^\"]+)\"")
    .find(rootProject.file("../package.json").readText())!!.groupValues[1]
val versionParts = clientVersion.split(".").map { it.takeWhile(Char::isDigit).ifEmpty { "0" }.toInt() }

// Release signing from android/keystore.properties or the environment (CI); unsigned otherwise
val keystoreProperties = Properties().apply {
    val file = rootProject.file("keystore.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
fun signingValue(key: String, env: String): String? = keystoreProperties.getProperty(key) ?: System.getenv(env)

android {
    namespace = "app.lanternfish"
    compileSdk = 35

    defaultConfig {
        applicationId = "app.lanternfish"
        // Fire OS 5 (first Fire TV Stick) is API 22
        minSdk = 22
        targetSdk = 35
        versionName = clientVersion
        versionCode = versionParts[0] * 1_000_000 + versionParts.getOrElse(1) { 0 } * 1_000 + versionParts.getOrElse(2) { 0 }
    }

    signingConfigs {
        val storeFile = signingValue("storeFile", "LANTERNFISH_KEYSTORE")
        if (storeFile != null) {
            create("release") {
                this.storeFile = file(storeFile)
                storePassword = signingValue("storePassword", "LANTERNFISH_KEYSTORE_PASSWORD")
                keyAlias = signingValue("keyAlias", "LANTERNFISH_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "LANTERNFISH_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.findByName("release")
        }
        debug {
            applicationIdSuffix = ".debug"
        }
    }

    sourceSets["main"].assets.srcDir(layout.buildDirectory.dir("generated/lanternfish-assets"))

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        buildConfig = true
    }
    lint {
        abortOnError = true
        // TV and phone in one APK is intentional
        disable += "MissingLeanbackSupport"
    }
}

// shared/nativeshell.js is the same file the webOS and Tizen apps use; copy it into the APK's assets
val copySharedAssets by tasks.registering(Copy::class) {
    from(rootProject.file("../shared/nativeshell.js"))
    into(layout.buildDirectory.dir("generated/lanternfish-assets/lanternfish"))
}
tasks.named("preBuild") { dependsOn(copySharedAssets) }

dependencies {
    testImplementation("junit:junit:4.13.2")
}
