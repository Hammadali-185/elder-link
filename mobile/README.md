# mobile

A new Flutter project.

## Getting Started

### Web login persistence (important)

This app uses `shared_preferences`. On **Flutter Web**, that persists to **browser `localStorage`**, which is scoped to the page origin: `http://host:port`.

When you run `flutter run -d chrome`, Flutter may pick a **different port each run**, so your saved login/credentials can appear “missing” after restarting the app.

- **Recommended (Windows/PowerShell)**:
  - Run `.\run_web.ps1` (uses a fixed port so login persists across restarts).
- **Manual**:
  - `flutter run -d chrome --web-port 55000`

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
