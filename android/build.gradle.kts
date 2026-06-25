plugins {
    id("com.google.gms.google-services") version "4.5.0" apply false
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
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    if (project.name == "file_picker") {
        project.plugins.apply("org.jetbrains.kotlin.android")
    }

    val configureProject = {
        if (project.hasProperty("android")) {
            val android = project.extensions.findByName("android")
            android?.let {
                try {
                    val m = it.javaClass.getMethod("compileSdkVersion", java.lang.Integer.TYPE)
                    m.invoke(it, 36)
                } catch (e: Exception) {
                    try {
                        val m = it.javaClass.getMethod("setCompileSdk", java.lang.Integer.TYPE)
                        m.invoke(it, 36)
                    } catch (e2: Exception) {
                        try {
                            val m = it.javaClass.getMethod("compileSdkVersion", String::class.java)
                            m.invoke(it, "android-36")
                        } catch (e3: Exception) {}
                    }
                }
            }
        }
    }

    if (project.state.executed) {
        configureProject()
    } else {
        project.afterEvaluate {
            configureProject()
        }
    }

    // HARDENING: devops-agent 2026-06-25
    // Force modern Kotlin language and API version for subprojects using deprecated versions (below 2.0)
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            val lang = languageVersion.orNull
            if (lang != null && lang < org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0) {
                languageVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0)
            }
            val api = apiVersion.orNull
            if (api != null && api < org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0) {
                apiVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0)
            }
        }
    }
}

