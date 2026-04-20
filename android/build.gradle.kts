allprojects {
    repositories {
        google()
        mavenCentral()
        // 备用镜像源（国内开发时可用）
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
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
// 兼容 AGP 8+：为未声明 namespace 的老插件（install_plugin 2.1.0 等）
// 从其 AndroidManifest.xml 的 package 属性回填 namespace，避免构建时
// "Namespace not specified" 报错。
// 必须在 evaluationDependsOn 之前注册，否则子项目早已完成 evaluate。
subprojects {
    afterEvaluate {
        val androidExt = project.extensions.findByName("android") ?: return@afterEvaluate
        val getNs = androidExt.javaClass.methods.firstOrNull { it.name == "getNamespace" }
        val setNs = androidExt.javaClass.methods.firstOrNull { it.name == "setNamespace" && it.parameterCount == 1 }
        if (getNs == null || setNs == null) return@afterEvaluate

        val current = getNs.invoke(androidExt) as? String
        if (!current.isNullOrEmpty()) return@afterEvaluate

        val manifestFile = project.file("src/main/AndroidManifest.xml")
        if (!manifestFile.exists()) return@afterEvaluate

        val pkg = Regex("""package\s*=\s*"([^"]+)"""")
            .find(manifestFile.readText())
            ?.groupValues?.getOrNull(1)
        if (!pkg.isNullOrEmpty()) {
            setNs.invoke(androidExt, pkg)
        }
    }
}

// 针对 install_plugin 2.1.0 的专项兜底：
// 该插件未显式配置 compileOptions/kotlinOptions，新版 Kotlin Gradle Plugin
// 默认 JVM target=17，与 AGP Java target=1.8 不一致，导致 "Inconsistent
// JVM-target compatibility" 构建失败。强制把它的 Kotlin target 降回 1.8 即可
// 与 Java target 对齐（不能改 Java 到 11，因为该插件 compileSdk < 30 时 AGP
// 会拒绝 Java 9+ source）。
// 只针对该项目处理，避免误伤其他已经正确配置的插件。
subprojects {
    if (project.name == "install_plugin") {
        afterEvaluate {
            val androidExt = project.extensions.findByName("android") ?: return@afterEvaluate
            runCatching {
                val ko = androidExt.javaClass.methods
                    .firstOrNull { it.name == "getKotlinOptions" }
                    ?.invoke(androidExt) ?: return@runCatching
                ko.javaClass.methods
                    .firstOrNull { it.name == "setJvmTarget" && it.parameterCount == 1 && it.parameterTypes[0] == String::class.java }
                    ?.invoke(ko, "1.8")
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
