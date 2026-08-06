import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Assinatura de release lida de android/key.properties, que NÃO é versionado
// (ver android/.gitignore). O arquivo key.properties.example, ao lado,
// documenta o formato.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "br.com.escalas.louvor_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "br.com.escalas.louvor_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // Sem a chave o build continua funcionando (útil para quem só
                // clona e quer rodar), mas o APK sai assinado com a chave de
                // debug -- que é pública e igual no mundo inteiro. O aviso
                // existe para isso não passar despercebido e o arquivo acabar
                // instalado no celular de alguém.
                signingConfig = signingConfigs.getByName("debug")
                logger.warn(
                    "\n*** ATENCAO: android/key.properties nao encontrado. " +
                        "O APK de release sera assinado com a CHAVE DE DEBUG. " +
                        "Nao distribua este arquivo: quem instalar nao " +
                        "conseguira atualizar para uma versao assinada de " +
                        "verdade sem desinstalar antes. ***\n",
                )
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
