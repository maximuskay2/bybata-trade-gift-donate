import com.android.build.gradle.LibraryExtension
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
    id("com.google.gms.google-services") version "4.3.15" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
val legacyJvmTargets = setOf(
    "qr_code_scanner",
    "share_plus",
    "share_plus_android",
    "uni_links",
    "sign_in_with_apple",
    "video_compress",
)
val jvm17Targets = setOf(
    "record_android",
    "stripe_android",
    "webview_flutter_android",
    "video_player_android",
)

fun LibraryExtension.applyJvm(java: JavaVersion) {
    compileOptions {
        sourceCompatibility = java
        targetCompatibility = java
    }
}

subprojects {
    project.evaluationDependsOn(":app")
    plugins.withId("org.jetbrains.kotlin.android") {
        tasks.withType<KotlinCompile>().configureEach {
            kotlinOptions.jvmTarget = when {
                legacyJvmTargets.contains(project.name) -> "1.8"
                jvm17Targets.contains(project.name) -> "17"
                else -> "11"
            }
        }
    }
    plugins.withId("com.android.library") {
        val androidExt = extensions.findByName("android")
        if (androidExt is LibraryExtension) {
            if (androidExt.namespace == null || androidExt.namespace!!.isBlank()) {
                val safeName = name.replace("-", "_")
                androidExt.namespace = "com.bybata.$safeName"
            }
            androidExt.compileSdk = 34
            when {
                legacyJvmTargets.contains(project.name) ->
                    androidExt.applyJvm(JavaVersion.VERSION_1_8)
                jvm17Targets.contains(project.name) ->
                    androidExt.applyJvm(JavaVersion.VERSION_17)
                else ->
                    androidExt.applyJvm(JavaVersion.VERSION_11)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
