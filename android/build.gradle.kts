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
}

