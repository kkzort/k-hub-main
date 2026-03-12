plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter eklentisi (Yeni sürümlerde bu gereklidir)
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase'i çalıştıran sihirli satır:
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.k_hub"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    defaultConfig {
        // Uygulamanın kimliği (Google'a kaydettiğin isimle aynı olmalı)
        applicationId = "com.example.k_hub"
        
        // --- BURASI ÇOK ÖNEMLİ ---
        // Firebase en az 23 istiyor, o yüzden burayı elle 23 yaptık.
        minSdk = flutter.minSdkVersion 
        // -------------------------
        
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // İmzalama ayarları (Varsayılan olarak debug anahtarını kullanır)
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
