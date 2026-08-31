plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// El identificador del paquete se puede pasar al compilar:
//   flutter run -Ppaquete=com.tuempresa.app
//
// Está así porque el servicio verifica que el paquete que pide la configuración
// esté registrado en tu comercio: con otro devuelve 409. Sin esto, cualquiera
// que clone el repositorio tiene que editar tres archivos antes de poder correr
// el ejemplo — y el que no lea el README se topa con un 409 que no explica nada.
val paqueteDeLaApp = (project.findProperty("paquete") as String?)
    ?: "com.juanpush.android1"

android {
    namespace = paqueteDeLaApp
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Lo exige flutter_local_notifications, que es lo que dibuja el aviso
        // cuando la app está abierta. Sin esto la compilación falla con
        // "requires core library desugaring to be enabled".
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = paqueteDeLaApp
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
