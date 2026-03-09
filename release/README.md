# ElderLink – Release APK

This folder is for the **built APK** (the actual installable app), not the source code.

## How to build and copy the APK here

1. **Install Android SDK** (required for `flutter build apk`):
   - Install [Android Studio](https://developer.android.com/studio) (includes SDK), or
   - Install [Android command-line tools](https://developer.android.com/studio#command-tools) and set `ANDROID_HOME`.

2. **If you see "There is not enough space on the disk" or NDK install fails:**
   - **Option A – Free space:** Free at least **5 GB** on the drive where the Android SDK is installed (usually `C:`). Then run the build again.
   - **Option B – Move SDK to another drive:** In Android Studio go to **File → Settings → Appearance & Behavior → System Settings → Android SDK**. Set **Android SDK location** to a folder on a drive with more space (e.g. `D:\Android\Sdk`). Set the `ANDROID_HOME` environment variable to that path. Then run the build again.
   - **Option C – Install NDK manually:** Free at least 2–3 GB, then in Android Studio open **Tools → SDK Manager → SDK Tools**, check **NDK (Side by side)**, click Apply. After it installs, from the project root run `.\build-and-copy-apk.ps1` again.

3. **From the project root**, run:
   ```powershell
   .\build-and-copy-apk.ps1
   ```
   Or from the `mobile` folder:
   ```bash
   flutter build apk
   ```
   Then copy:
   `mobile\build\app\outputs\flutter-apk\app-release.apk`
   to this `release` folder.

4. **Install on phone**: Copy `ElderLink-release.apk` (or `app-release.apk`) to your phone and open it; allow “Install from unknown sources” if asked.
