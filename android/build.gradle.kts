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

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
