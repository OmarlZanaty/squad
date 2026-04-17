allprojects {
    repositories {
        // EXCLUSIVE: Huawei Cloud Mirrors ONLY
        maven { url = uri("https://repo.huaweicloud.com/repository/maven/" ) }
        maven { url = uri("https://repo.huaweicloud.com/repository/google/" ) }
        maven { url = uri("https://repo.huaweicloud.com/repository/gradle-plugin/" ) }
    }
}

rootProject.layout.buildDirectory.value(rootProject.layout.projectDirectory.dir("../build"))

subprojects {
    project.layout.buildDirectory.value(rootProject.layout.buildDirectory.dir(project.name))
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
