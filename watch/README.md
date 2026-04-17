# ElderLink — Watch app

Flutter UI aimed at small round / watch-class screens: large touch targets, high contrast, simple navigation. Talks to the same **Node/MongoDB** backend as `mobile/` when host/port are configured.

## Features

### Home (radial wheel)

- **Medicine** — today’s schedule from the API; taken / snooze / missed flows
- **Switch** — pick the active resident (recent history + facility elders from `GET /api/elders`)
- **Clock**
- **My Info** — profile synced with the server (`sync-from-watch`)
- **Music** — playback with optional session reporting
- **Settings** — language, brightness, **backend host/port** (persisted)
- **Health** — vitals-style monitoring and readings
- **Panic** — center control; hold-to-confirm where applicable

### Medicine

- Loads schedules for the **active** elder; scheduling uses **Karachi** wall date for “today” (`lib/karachi_time.dart`)
- Dose-time alarms via local monitoring (`medicine_schedule_monitor.dart`)
- **Cross-elder banner:** if another facility elder has **pending** doses today, a banner can prompt switching (`cross_elder_medicine_notifier.dart`)

### Other

- Panic and health flows integrate with backend APIs where implemented
- Urdu/English strings via app localizations

## Backend connection

Defaults: `WATCH_API_HOST` / `WATCH_API_PORT` (see `lib/services/api_service.dart`), typically `192.168.137.1:5000`. Override at run/build with `--dart-define=...` or set host/port in **Settings** on the device.

## Getting started

```bash
cd watch
flutter pub get
flutter run
```

Android emulator: often `--dart-define=WATCH_API_HOST=10.0.2.2`.

## Project structure (partial)

```
lib/
├── main.dart
├── karachi_time.dart
├── screens/
│   ├── home_screen.dart
│   ├── switch_elder_screen.dart
│   ├── medicine_reminder_screen.dart
│   └── ...
├── services/
│   ├── api_service.dart
│   ├── medicine_schedule_monitor.dart
│   ├── cross_elder_medicine_notifier.dart
│   └── ...
└── ui/
    ├── cross_elder_medicine_banner_overlay.dart
    └── ...
```

## Dependencies

See `pubspec.yaml` (e.g. `http`, `shared_preferences`, `audioplayers`, `vibration`, `timezone`, …).
