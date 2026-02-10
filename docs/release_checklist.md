# Release Checklist

## 0) Pre-flight gates (must pass)
1. `dart format <changed files>`
2. `flutter analyze 2>&1 | Select-String " error - "` (must return no matches)
3. `flutter analyze --no-fatal-warnings --no-fatal-infos` (must exit 0)
4. `flutter test` (must be green repo-wide)

## 0.1) Platform files are tracked
1. Root `.gitignore` keeps `android/` and `ios/` mostly ignored but explicitly unignores store-pack files.
2. Required tracked Android files:
- `android/app/build.gradle.kts`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/res/drawable/launch_background.xml`
- `android/app/src/main/res/drawable-v21/launch_background.xml`
- `android/app/src/main/res/mipmap-*/ic_launcher.png`
- `android/app/src/main/res/mipmap-*/ic_launcher_round.png`
- `android/key.properties.example`
3. Required tracked iOS files:
- `ios/Runner/Info.plist`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/*`
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/*`
4. If any expected file is missing from `git status`, re-check `.gitignore` negation rules first.

## 1) Android signing and AAB (deterministic)
1. Generate an upload keystore locally (do not commit keystore):
```powershell
keytool -genkeypair -v -keystore "$env:USERPROFILE\\.android\\bitflow-upload.jks" -alias upload -keyalg RSA -keysize 2048 -validity 10000
```
2. Create `android/key.properties` (do not commit) using `android/key.properties.example` as reference.
3. `android/key.properties` format:
```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=C:\\Users\\<you>\\.android\\bitflow-upload.jks
```
4. Release signing behavior:
- `android/app/build.gradle.kts` loads `key.properties` when present and signs release with `signingConfigs.release`.
- If `key.properties` is absent, it falls back to debug signing (not for store upload).
5. Build release artifacts:
- `flutter build appbundle --release`
- `flutter build apk --release`
6. Expected outputs:
- `build/app/outputs/bundle/release/app-release.aab`
- `build/app/outputs/flutter-apk/app-release.apk`

## 1.1) Windows Android SDK setup
1. Install Android SDK (Android Studio or command line tools).
2. Set environment variables and verify tooling.
3. Accept licenses before first release build.

PowerShell quick setup example:
```powershell
$env:ANDROID_HOME = "C:\\Users\\<you>\\AppData\\Local\\Android\\Sdk"
$env:Path += ";$env:ANDROID_HOME\\platform-tools;$env:ANDROID_HOME\\cmdline-tools\\latest\\bin"
flutter doctor --android-licenses
flutter doctor -v
flutter build appbundle --release
```

## 1.2) Release Preflight (copy/paste PowerShell)
```powershell
$env:ANDROID_HOME = "C:\Users\<you>\AppData\Local\Android\Sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:Path += ";$env:ANDROID_HOME\platform-tools;$env:ANDROID_HOME\cmdline-tools\latest\bin"

flutter doctor --android-licenses
powershell -ExecutionPolicy Bypass -File .\scripts\doctor_android.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\release_android.ps1
```

Expected release output:
- `build/app/outputs/bundle/release/app-release.aab`

## 2) iOS (IPA)
1. Open `ios/Runner.xcworkspace` in Xcode and configure Team / Bundle ID / signing.
2. Confirm runtime permission keys in `ios/Runner/Info.plist`:
- `NSCameraUsageDescription`
- `NSMicrophoneUsageDescription`
- `NSPhotoLibraryUsageDescription`
- `NSPhotoLibraryAddUsageDescription`
- `NSLocationWhenInUseUsageDescription`
3. Build IPA:
- `flutter build ipa --release`
4. Artifact:
- `build/ios/ipa/*.ipa`

## 3) Web
1. Confirm `web/index.html` keeps `<base href="$FLUTTER_BASE_HREF" />`.
2. Build with target base href when deploying under subpath, for example:
- `flutter build web --release --base-href /bitacora_web/`
3. Confirm `web/manifest.json` brand fields (name/description/icons) are correct.

## 4) Icons and splash sanity
1. Source reference for generated app icons:
- `assets_branding/bitflow_mark_1024.png`
2. Android launcher icons present in all mipmap densities:
- `ic_launcher.png`
- `ic_launcher_round.png`
3. Android launch splash uses branded asset path:
- `android/app/src/main/res/drawable/launch_background.xml`
- `android/app/src/main/res/drawable-v21/launch_background.xml`
4. iOS AppIcon set populated:
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`
- all required `Icon-App-*.png` files
5. iOS LaunchImage set populated:
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json`
- `LaunchImage.png`, `LaunchImage@2x.png`, `LaunchImage@3x.png`

## 5) Store metadata hooks (<=2 taps from Start and Sheets)
1. About (`Acerca de`)
2. Privacy (`Privacidad`)
3. Terms (`Terminos`)
4. Diagnostics (`Diagnostico / Soporte`)
5. Licenses (`Licencias`)
