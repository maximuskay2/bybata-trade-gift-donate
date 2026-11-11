import com.android.build.gradle.LibraryExtension
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
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

/** Older plugins that still need Java 8. Everything else prefers JVM 17. */
val legacyJvmTargets = setOf(
    "qr_code_scanner",
    "share_plus",
    "share_plus_android",
    "uni_links",
    "sign_in_with_apple",
    "video_compress",
)

fun Project.preferredJava(): JavaVersion =
    if (legacyJvmTargets.contains(name)) JavaVersion.VERSION_1_8 else JavaVersion.VERSION_17

fun jvmTargetFor(java: JavaVersion): JvmTarget =
    when (java) {
        JavaVersion.VERSION_1_8 -> JvmTarget.JVM_1_8
        JavaVersion.VERSION_11 -> JvmTarget.JVM_11
        else -> JvmTarget.JVM_17
    }

/** AGP 8.11+ rejects package= in library manifests; keep namespace in Gradle instead. */
fun stripManifestPackage(project: Project) {
    val manifest = project.file("src/main/AndroidManifest.xml")
    if (!manifest.isFile) return
    val original = manifest.readText()
    val updated = original.replace(Regex("""\s*package="[^"]*""""), "")
    if (updated != original) {
        manifest.writeText(updated)
    }
}

/**
 * Force Kotlin's jvmTarget to match the module's Java targetCompatibility.
 * Reading compileOptions is safe after finalization; writing it is not.
 */
fun Project.alignKotlinJvm() {
    tasks.withType<KotlinCompile>().configureEach {
        val androidExt = extensions.findByName("android") as? LibraryExtension
        val java =
            try {
                androidExt?.compileOptions?.targetCompatibility
            } catch (_: Exception) {
                null
            } ?: preferredJava()
        compilerOptions {
            jvmTarget.set(jvmTargetFor(java))
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")

    plugins.withId("org.jetbrains.kotlin.android") {
        alignKotlinJvm()
    }

    plugins.withId("com.android.library") {
        stripManifestPackage(project)
        val androidExt = extensions.findByName("android")
        if (androidExt is LibraryExtension) {
            if (androidExt.namespace == null || androidExt.namespace!!.isBlank()) {
                val safeName = name.replace("-", "_")
                androidExt.namespace = "com.bybata.$safeName"
            }
            androidExt.compileSdk = 34
            // Prefer JVM 17 early. If AGP already finalized this, skip and
            // let alignKotlinJvm() follow whatever Java value stuck.
            try {
                androidExt.compileOptions {
                    sourceCompatibility = preferredJava()
                    targetCompatibility = preferredJava()
                }
            } catch (_: IllegalStateException) {
                // finalized — leave Java alone
            }
        }
        alignKotlinJvm()
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
