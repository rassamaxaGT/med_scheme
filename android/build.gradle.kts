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
    plugins.withId("com.android.library") {
        configure<com.android.build.gradle.LibraryExtension> {
            compileSdk = 34
            if (namespace.isNullOrEmpty()) {
                namespace = "com.example.${project.name}"
            }
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
        
        // Удаляем package="..." из AndroidManifest.xml зависимостей для совместимости с AGP 8.0+
        val manifestFile = file("src/main/AndroidManifest.xml")
        if (manifestFile.exists()) {
            try {
                var content = manifestFile.readText()
                if (content.contains("package=")) {
                    content = content.replace(Regex("""package="[^"]*""""), "")
                    manifestFile.writeText(content)
                    logger.quiet("Stripped package attribute from manifest of ${project.name}")
                }
            } catch (e: Exception) {
                logger.warn("Failed to strip package from ${project.name}: $e")
            }
        }
    }

    if (project.name != "app") {
        val applyLibraryConfig = {
            plugins.withId("com.android.library") {
                configure<com.android.build.gradle.LibraryExtension> {
                    compileSdk = 34
                }
            }
        }
        if (state.executed) {
            applyLibraryConfig()
        } else {
            afterEvaluate {
                applyLibraryConfig()
            }
        }
    }

    plugins.withId("com.android.application") {
        configure<com.android.build.gradle.AppExtension> {
            if (namespace.isNullOrEmpty()) {
                namespace = "com.example.${project.name}"
            }
        }
    }

    // Устанавливаем совместимость Kotlin с версией 17
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.core" && requested.name == "core") {
                useVersion("1.13.1")
            }
            if (requested.group == "androidx.core" && requested.name == "core-ktx") {
                useVersion("1.13.1")
            }
        }
    }
}
