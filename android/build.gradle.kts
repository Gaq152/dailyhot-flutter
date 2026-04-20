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

// 统一子项目 JVM target 到 Java 11（与 :app 对齐）
// 老插件（install_plugin 2.1.0 等）未显式配置 compileOptions/kotlinOptions，
// 新版 Kotlin Gradle Plugin 默认 JVM target=17，与 AGP Java target=1.8 不一致，
// 导致 "Inconsistent JVM-target compatibility" 构建失败。
subprojects {
    afterEvaluate {
        val androidExt = project.extensions.findByName("android") ?: return@afterEvaluate
        // Java 编译目标
        runCatching {
            val co = androidExt.javaClass.methods
                .firstOrNull { it.name == "getCompileOptions" }
                ?.invoke(androidExt) ?: return@runCatching
            co.javaClass.methods
                .firstOrNull { it.name == "setSourceCompatibility" && it.parameterTypes.singleOrNull() == JavaVersion::class.java }
                ?.invoke(co, JavaVersion.VERSION_11)
            co.javaClass.methods
                .firstOrNull { it.name == "setTargetCompatibility" && it.parameterTypes.singleOrNull() == JavaVersion::class.java }
                ?.invoke(co, JavaVersion.VERSION_11)
        }
        // Kotlin 编译目标
        runCatching {
            val ko = androidExt.javaClass.methods
                .firstOrNull { it.name == "getKotlinOptions" }
                ?.invoke(androidExt) ?: return@runCatching
            ko.javaClass.methods
                .firstOrNull { it.name == "setJvmTarget" && it.parameterCount == 1 && it.parameterTypes[0] == String::class.java }
                ?.invoke(ko, "11")
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
