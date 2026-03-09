$ErrorActionPreference = "Stop"

# Flutter Web SharedPreferences uses browser localStorage, which is scoped per-origin (host+port).
# In `flutter run`, the web server port can change each run, which makes localStorage look "empty".
# Using a fixed --web-port ensures your saved info persists across restarts.

$port = 55001  # Different port from mobile app

Write-Host "Running Watch app on fixed port $port..."
flutter run -d chrome --web-port $port
