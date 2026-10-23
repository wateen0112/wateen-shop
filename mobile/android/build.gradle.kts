allprojects {
    repositories {
        // Google's Maven host (dl.google.com) is blocked on some networks, so the
        // Aliyun mirror is tried first. Maven Central is reachable directly.
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
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
subprojects {
    // Some plugins (e.g. printing 5.14.x) still pin a 7.x Android Gradle Plugin in
    // their own buildscript, which cannot run on Gradle 8.14. Force the AGP version
    // used by the app instead of patching the plugin sources.
    buildscript {
        configurations.configureEach {
            resolutionStrategy.force("com.android.tools.build:gradle:8.11.1")
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
