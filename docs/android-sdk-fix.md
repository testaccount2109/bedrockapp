# Android SDK Fix

Your release build failed with:

```text
[!] No Android SDK found. Try setting the ANDROID_HOME environment variable.
```

This means Flutter is installed, but the Android SDK is either missing or not configured.

## Option A: Install Android Studio

1. Install Android Studio.
2. Open Android Studio.
3. Open `More Actions -> SDK Manager`.
4. Install:
   - Android SDK Platform 35
   - Android SDK Build-Tools
   - Android SDK Platform-Tools
   - Android SDK Command-line Tools latest
5. The usual SDK path on Windows is:

```text
C:\Users\benja\AppData\Local\Android\Sdk
```

6. From the HostConnect project root, run:

```powershell
.\tools\configure_android_sdk.ps1 -SdkPath "C:\Users\benja\AppData\Local\Android\Sdk"
```

7. Restart PowerShell.
8. Run:

```powershell
flutter doctor -v
flutter doctor --android-licenses
flutter build apk --release
```

## Option B: You Already Have an SDK Somewhere Else

Find the SDK folder. It must contain:

```text
platform-tools
platforms
build-tools
```

Then run:

```powershell
.\tools\configure_android_sdk.ps1 -SdkPath "D:\Path\To\Android\Sdk"
```

Restart PowerShell and build again.

## Manual Project-Only Fix

You can also edit:

```text
android/local.properties
```

Expected content:

```properties
flutter.sdk=C:\\flutter
sdk.dir=C:\\Users\\benja\\AppData\\Local\\Android\\Sdk
```

This fixes the project, but setting `ANDROID_HOME` is still recommended for Flutter and Gradle tooling.
