# Release signing in `android/app/build.gradle` (Groovy DSL)

Reads the upload-key credentials from `android/key.properties` (git-ignored — see
[`key.properties.example`](key.properties.example)) and applies them to the **release** build
type, with R8 minification + resource shrinking. This is the house default; a Kotlin-DSL
(`build.gradle.kts`) variant follows at the bottom.

## 1. Load `key.properties` at the top of the file

Put this **above** the `android { }` block:

```gradle
// android/app/build.gradle  (Groovy DSL)
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

> `rootProject.file('key.properties')` resolves to `android/key.properties` (one level up from
> `android/app/`), matching the path in the example file.

## 2. Define the signing config + release build type

Inside `android { ... }`:

```gradle
android {
    // ...namespace, compileSdk, defaultConfig (versionCode/versionName come from Flutter)...

    signingConfigs {
        release {
            // Fail loudly if the file is missing instead of silently debug-signing.
            if (keystorePropertiesFile.exists()) {
                keyAlias keystoreProperties['keyAlias']
                keyPassword keystoreProperties['keyPassword']
                storeFile file(keystoreProperties['storeFile'])
                storePassword keystoreProperties['storePassword']
            }
        }
    }

    buildTypes {
        release {
            // Use the upload key — NOT signingConfigs.debug.
            signingConfig signingConfigs.release

            minifyEnabled true          // R8 code shrinking + obfuscation
            shrinkResources true        // drop unused resources (requires minifyEnabled)
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'),
                          'proguard-rules.pro'
        }
    }
}
```

- **`signingConfig signingConfigs.release`** is the critical line — without it, `flutter build`
  falls back to the debug key and Play will reject the upload.
- `minifyEnabled` + `shrinkResources` go together; keep a `proguard-rules.pro` with keep-rules for
  any reflection-based libs (skill 13 §4).
- Dart-level obfuscation is separate — pass `--obfuscate --split-debug-info=build/symbols` to
  `flutter build appbundle` (skill 13 / 23).

## 3. (Optional) Kotlin DSL — `build.gradle.kts`

If the project uses KTS instead of Groovy:

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}
```
