# ElderLink

Health and safety platform for elderly residents and care staff: **Flutter** apps (phone + watch-style UI), **Node.js/Express** API, and **MongoDB**. Staff manage elders, medicines, readings, and alerts; residents use simplified UIs on phone or watch.

## Repository layout

| Path | Role |
|------|------|
| `backend/` | REST API, MongoDB models, medicine assignment / event helpers |
| `mobile/` | Staff app: dashboards, elders, medicines, Firebase auth, notifications |
| `watch/` | Resident watch UI: reminders, panic, vitals, music, resident switch |

## Current capabilities (high level)

**Backend**

- Elders, medicines, readings, heart alerts, music sessions
- Strict MongoDB ObjectId handling and elder resolution for API calls
- Medicine-related persistence and outbox-style event helpers (see `backend/models/medicineEvent.js`, `backend/services/medicineEventOutbox.js`)

**Mobile (`mobile/`)**

- Firebase Authentication for staff (email/password and related flows)
- Admin / staff areas: live data, logs, roles, settings
- Elders and medicines CRUD against the Node API
- **Backend connection**: host/port stored in app settings (defaults + `--dart-define=MOBILE_API_HOST` / `MOBILE_API_PORT`); see `mobile/lib/screens/backend_settings_screen.dart`
- Alerts, music, profile / privacy screens

**Watch (`watch/`)**

- Radial home: Medicine, **Switch** (change active resident), Clock, My Info, Music, Settings, Health; panic in the center
- Medicine schedule from API; **Karachi** wall-clock for “today” scheduling
- **Switch resident**: recent residents plus facility list from `GET /api/elders` merged into device history
- **Cross-elder banner**: if another resident has pending doses today, optional prompt to switch
- Heart rate / BP style monitoring UI, readings API, panic flow, music with session reporting (when enabled)

## Documentation

- **Quick setup:** [README_SETUP.md](README_SETUP.md)
- **Detailed setup:** [SETUP_INSTRUCTIONS.md](SETUP_INSTRUCTIONS.md)
- **Watch-only notes:** [watch/README.md](watch/README.md)

## Tech stack

Flutter, Dart, Node.js, Express, MongoDB, REST, Firebase (mobile).
