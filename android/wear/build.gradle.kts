// Rejnox pre hodinky s Wear OS (Galaxy Watch 4+, Pixel Watch, …):
// tréning s tepom a kalóriami naživo cez Health Services, spojenie
// s telefónom cez Wearable Data Layer.
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

// Verzia z pubspec.yaml ("1.2.3+45"), aby hodinky sedeli s telefónom.
val pubspecVersion: Pair<String, Int> =
    rootProject.file("../pubspec.yaml").readLines()
        .first { it.startsWith("version:") }
        .substringAfter(":").trim()
        .split("+")
        .let { it[0] to (it.getOrNull(1)?.toIntOrNull() ?: 1) }

// Číslo zostavenia sa dá prepísať (-PbuildNumber=…), napr. v Codemagicu.
val buildNumber: Int =
    (findProperty("buildNumber") as String?)?.toIntOrNull() ?: pubspecVersion.second

android {
    namespace = "com.rejnox.rejnox.wear"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Rovnaké ID ako appka v telefóne: Data Layer spojí len appky
        // s rovnakým ID a podpisom.
        applicationId = "com.rejnox.rejnox"
        // Wear OS 3+ (Health Services).
        minSdk = 30
        targetSdk = 35
        versionName = pubspecVersion.first
        // Google Play: hodinky a telefón v jednej appke potrebujú rôzne čísla.
        versionCode = 1_000_000_000 + buildNumber
    }

    buildTypes {
        release {
            // Rovnaký podpis ako appka v telefóne (zatiaľ debug kľúč).
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.16.0")
    implementation("androidx.activity:activity-ktx:1.10.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.health:health-services-client:1.1.0")
    implementation("androidx.concurrent:concurrent-futures-ktx:1.3.0")
    implementation("com.google.android.gms:play-services-wearable:19.0.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.10.2")
}
