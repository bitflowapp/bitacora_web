# Android Emulator QA Report

Date: 2026-04-28

Branch: `premium-linkedin-real-app`

## Environment

- AVD: `BitFlow_QA_API36`
- Device id: `emulator-5554`
- Model: `sdk_gphone64_x86_64`
- Android: 16, API 36
- Application id: `com.example.bitacora_web`
- APK tested: `build\app\outputs\flutter-apk\app-debug.apk`

## Evidence

- Landing: `docs/qa/android_emulator/qa_android_01_landing_fixed.png`
- Home: `docs/qa/android_emulator/qa_android_02_home_app.png`
- Editor: `docs/qa/android_emulator/qa_android_03_editor.png`
- Logcat: `docs/qa/android_emulator/qa_android_logcat_final.txt`
- UI dumps: `window_landing_fixed.xml`, `window_app_home.xml`, `window_editor.xml`

## Flows Tested

- App launch from Android launcher.
- Landing screen renders and `Probar ahora` routes into the app.
- Home/workspace renders with premium visual system.
- New blank sheet flow opens the editor.
- Editor renders toolbar, save/export actions, quick actions, first-run onboarding, and grid.
- Attach/GPS entry points are visible in quick actions.
- Export entry point is visible in the editor toolbar.

## Bugs Found

- Blocker: startup blank screen on Android debug caused by mobile layout flex assertions on the landing page. Fixed.
- Major: home quick action tiles and header could overflow on phone constraints. Fixed.
- Minor: visible mojibake in editor helper copy (`Ã‚Â·`) and boot copy. Fixed.
- Polish: Android package/application id still uses `com.example.bitacora_web`; this was not changed in this QA pass.

## Log Review

The final logcat does not show `FATAL EXCEPTION`, app `AndroidRuntime` crash, `MissingPluginException`, or active Flutter layout assertions after the fixes. AndroidRuntime lines in the log are from shell/uiautomator commands.

## Not Covered

- Camera capture, microphone recording, file picker, PDF/XLSX/ZIP export execution, GPS permission dialogs, rotation, and persistence reopen were not fully exercised after the startup blocker fix. The UI entry points were verified, but these flows need a second emulator pass now that launch/home/editor are stable.

## Recommendation

Ready for PR with the Android startup/layout fixes. Before a client demo, run a second QA pass focused only on permissions, attachments, GPS, audio, export outputs, rotation, and persistence.
