// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import org.gradle.api.JavaVersion
import org.jetbrains.kotlin.gradle.plugin.KotlinAndroidPluginWrapper

apply<FlutterPluginKts>()

class FlutterPluginKts : Plugin<Project> {
    override fun apply(project: Project) {
        // Validate that the provided Gradle, Java, AGP, and KGP versions are all within our
        // supported range.
        if (!project.hasProperty("skipDependencyChecks")) {
            DependencyVersionChecker.checkDependencyVersions(project)
        }

        // Use withGroovyBuilder and getProperty() to access Groovy metaprogramming.
        project.withGroovyBuilder {
            getProperty("android").withGroovyBuilder {
                getProperty("defaultConfig").withGroovyBuilder {
                    if (project.hasProperty("multidex-enabled") &&
                        project.property("multidex-enabled").toString().toBoolean()) {
                        setProperty("multiDexEnabled", true)
                        getProperty("manifestPlaceholders").withGroovyBuilder {
                            setProperty("applicationName", "io.flutter.app.FlutterMultiDexApplication")
                        }
                    } else {
                        var baseApplicationName: String = "android.app.Application"
                        if (project.hasProperty("base-application-name")) {
                            baseApplicationName = project.property("base-application-name").toString()
                        }
                        // Setting to android.app.Application is the same as omitting the attribute.
                        getProperty("manifestPlaceholders").withGroovyBuilder {
                            setProperty("applicationName", baseApplicationName)
                        }
                    }
                }
            }
        }
    }
}

class DependencyVersionChecker {
    companion object {
        // The following versions define our support policy for Gradle, Java, AGP, and KGP.
        // All "error" versions are currently set to 0 as this policy is new. They will be increased
        // to match the current values of the "warn" versions in the next release.
        // Before updating any "error" version, ensure that you have updated the corresponding
        // "warn" version for a full release to provide advanced warning. See
        // flutter.dev/go/android-dependency-versions for more.
        val warnGradleVersion : Version = Version(7,0,2)
        val errorGradleVersion : Version = Version(0,0,0)

        val warnJavaVersion : JavaVersion = JavaVersion.VERSION_11
        val errorJavaVersion : JavaVersion = JavaVersion.VERSION_1_1

        val warnAGPVersion : Version = Version(7,0,0)
        val errorAGPVersion : Version = Version(0,0,0)

        val warnKGPVersion : Version = Version(1,5,0)
        val errorKGPVersion : Version = Version(0,0,0)

        /**
         * Checks if the project's Android build time dependencies are each within the respective
         * version range that we support. When we can't find a version for a given dependency
         * we treat it as within the range for the purpose of this check.
         */
        fun checkDependencyVersions(project : Project) {
            var gradleVersion : Version? = null
            var javaVersion : JavaVersion? = null
            var agpVersion : Version? = null
            var kgpVersion : Version? = null

            try {
                gradleVersion = getGradleVersion(project)
            } catch (ignored : Exception){
                project.logger.error("Warning: unable to detect project Gradle version. Skipping " +
                        "version checking.")
            }
            if (gradleVersion != null) checkGradleVersion(gradleVersion!!, project)
            try {
                javaVersion = getJavaVersion(project)
            } catch (ignored : Exception){
                project.logger.error("Warning: unable to detect project Java version. Skipping " +
                        "version checking.")
            }
            if (javaVersion != null) checkJavaVersion(javaVersion!!, project)
            try {
                agpVersion = getAGPVersion(project)
            } catch (ignored : Exception){
                project.logger.error("Warning: unable to detect project AGP version. Skipping " +
                        "version checking. " + ignored)
            }
            if (agpVersion != null) checkAGPVersion(agpVersion!!, project)
            try {
                kgpVersion = getKGPVersion(project)
            } catch (ignored : Exception){
                project.logger.error("Warning: unable to detect project KGP version. Skipping " +
                        "version checking.")
            }
            if (kgpVersion != null) checkKGPVersion(kgpVersion!!, project)
        }

        // https://docs.gradle.org/current/kotlin-dsl/gradle/org.gradle.api.invocation/-gradle/index.html#-837060600%2FFunctions%2F-1793262594
        fun getGradleVersion(project : Project) : Version {
            return Version.fromString(project.gradle.getGradleVersion())
        }

        // https://docs.gradle.org/current/kotlin-dsl/gradle/org.gradle.api/-java-version/index.html#-1790786897%2FFunctions%2F-1793262594
        fun getJavaVersion(project : Project) : JavaVersion {
            return JavaVersion.current()
        }

        // This approach is taken from AGP's own version checking plugin:
        // https://android.googlesource.com/platform/tools/base/+/studio-master-dev/build-system/gradle-core/src/main/java/com/android/build/gradle/internal/utils/agpVersionChecker.kt#58.
        fun getAGPVersion(project: Project): Version? {
            var agpVersion: Version? = null
            try {
                agpVersion = Version.fromString(
                    project.plugins.getPlugin("com.android.base")::class.java.classLoader.loadClass(
                        com.android.Version::class.java.name
                    ).fields.find { it.name == "ANDROID_GRADLE_PLUGIN_VERSION" }!!
                        .get(null) as String
                )
            } catch (ignored: ClassNotFoundException) {
                // Use deprecated Version class as it exists in older AGP (com.android.Version) does
                // not exist in those versions.
                agpVersion = Version.fromString(
                    project.plugins.getPlugin("com.android.base")::class.java.classLoader.loadClass(
                        com.android.builder.model.Version::class.java.name
                    ).fields.find { it.name == "ANDROID_GRADLE_PLUGIN_VERSION" }!!
                        .get(null) as String
                )
            }
            return agpVersion
        }

        fun getKGPVersion(project : Project) : Version {
            try {
//                println(kotlinPlugin!!.javaClass.kotlin.members.first {it.name == "kotlinPluginVersion"}!!.call(kotlinPlugin))
//                println(kotlinPlugin!!.javaClass.kotlin.members.first {it.name == "pluginVersion"}!!.call(kotlinPlugin))
//                println(kotlinPlugin!!.javaClass.kotlin.members.first {it.name == "kotlinPluginVersion"}!!.call(kotlinPlugin))
//                println("gray")
//                project.plugins.withId("org.jetbrains.kotlin.android") {
//                    println(.version)
//                }
                //println(project.plugins.getPlugin("org.jetbrains.kotlin.android")::class.java.classLoader.loadClass(KotlinAndroidPluginWrapper::class.java.name).fields.find {println(it.name) ; it.name == "pluginVersion"})
                //println("gray + " + KotlinAndroidPluginWrapper::class.java.getFields().get(0))
                //println(project.getPlugins()
                //    .findPlugin(KotlinAndroidPluginWrapper::class.java)!!.pluginVersion)
                //                kotlinPlugin!!::class.members.forEach {
//                    try {
//                        println(it.name)
//                        println(it.call(kotlinPlugin))
//                    } catch (ignored: Exception) {
//
//                    }
//
//                }

                val kotlinPlugin = project.getPlugins()
                    .findPlugin(KotlinAndroidPluginWrapper::class.java)!!
                val versionfield = kotlinPlugin.javaClass.kotlin.members.first {it.name == "pluginVersion" || it.name == "kotlinPluginVersion"}
                if (versionfield != null) {
                    return Version.fromString(versionfield!!.call(kotlinPlugin) as String)
                }
                // Can't determine version.
                return Version(0,0,0)

            } catch (ignored : Exception) {
                println(ignored)
            }
            return Version(0,0,0)

        }

        private fun getErrorMessage(dependencyName : String,
                                    versionString : String,
                                    errorVersion : String) : String {
            return "Error: Your project's $dependencyName version ($versionString) is lower " +
                    "than Flutter's minimum supported version of $errorVersion. Please upgrade " +
                    "your $dependencyName version. \nAlternatively, use the flag " +
                    "\"--android-skip-build-dependency-validation\" to bypass this check."
        }

        fun checkGradleVersion(version : Version, project : Project) {
            println("Gradle version is: " + version.toString())
            if (version < errorGradleVersion) {
                throw GradleException(
                    getErrorMessage(
                        "Gradle",
                        version.toString(),
                        errorGradleVersion.toString()
                    )
                )
            }
            else if (version < warnGradleVersion) {
                project.logger.error("Warning: Flutter support for your project's Gradle version " +
                        "($version) will soon be dropped. Please upgrade your Gradle version soon. " +
                        "\nAlternatively, use the flag \"--android-skip-build-dependency-validation\"" +
                        " to bypass this check.")
            }
        }

        fun checkJavaVersion(version : JavaVersion, project : Project) {
            println("Java version is: " + version.toString())
            if (version < errorJavaVersion) {
                throw GradleException(
                    getErrorMessage(
                        "Java",
                        version.toString(),
                        errorJavaVersion.toString()
                    )
                )
            }
            else if (version < warnJavaVersion) {
                project.logger.error("Warning: Flutter support for your project's Java version " +
                        "($version) will soon be dropped. Please upgrade your Java version soon. " +
                        "\nAlternatively, use the flag \"--android-skip-build-dependency-validation\"" +
                        " to bypass this check.")
            }
        }

        fun checkAGPVersion(version : Version, project : Project) {
            println("AGP version is: " + version.toString())
            if (version < errorAGPVersion) {
                throw GradleException(
                    getErrorMessage(
                        "AGP",
                        version.toString(),
                        errorAGPVersion.toString()
                    )
                )
            }
            else if (version < warnAGPVersion) {
                project.logger.error("Warning: Flutter support for your project's Android Gradle Plugin" +
                        " version ($version) will soon be dropped. Please upgrade your AGP version soon. " +
                        "\nAlternatively, use the flag \"--android-skip-build-dependency-validation\"" +
                        " to bypass this check.")
            }
        }

        fun checkKGPVersion(version : Version, project : Project) {
            println("KGP version is: " + version.toString())
            if (version < errorKGPVersion) {
                throw GradleException(
                    getErrorMessage(
                        "Kotlin",
                        version.toString(),
                        errorKGPVersion.toString()
                    )
                )
            }
            else if (version < warnKGPVersion) {
                project.logger.error("Warning: Flutter support for your project's Kotlin version " +
                        "($version) will soon be dropped. Please upgrade your Kotlin version soon. " +
                        "\nAlternatively, use the flag \"--android-skip-build-dependency-validation\"" +
                        " to bypass this check.")
            }
        }
    }
}


// Helper class to parse the versions that are provided as plain strings (Gradle, Kotlin) and
// perform easy comparisons.
class Version(val major : Int, val minor : Int, val patch : Int) : Comparable<Version> {
    companion object {
        fun fromString(version : String) : Version {
            val asList : List<String> = version.split(".")
            return Version(
                major = asList.getOrElse(0, {"0"}).toInt(),
                minor = asList.getOrElse(1, {"0"}).toInt(),
                patch = asList.getOrElse(2, {"0"}).toInt()
            )
        }
    }
    override fun compareTo(otherVersion : Version) : Int {
        if (major != otherVersion.major) {
            return major - otherVersion.major
        }
        if (minor != otherVersion.minor) {
            return minor - otherVersion.minor
        }
        if (patch != otherVersion.patch) {
            return patch - otherVersion.patch
        }
        return 0
    }
    override fun toString() : String {
        return major.toString() + "." + minor.toString() + "." + patch.toString()
    }
}
