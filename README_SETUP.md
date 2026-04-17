# Quick Setup Guide for New Users

## What You Need to Change

### 1. Backend Configuration (MongoDB Atlas)

**File:** `backend/.env` (create this file)

Create a new file called `.env` in the `backend` folder with this content:

```
MONGO_URI=mongodb+srv://YOUR_USERNAME:YOUR_PASSWORD@YOUR_CLUSTER.mongodb.net/elderlink?retryWrites=true&w=majority
PORT=5000
```

**How to get your MongoDB Atlas connection string:**

1. Go to https://www.mongodb.com/cloud/atlas
2. Create a free account
3. Create a cluster (M0 Free tier)
4. Create a database user (username + password)
5. Whitelist your IP address (or allow from anywhere for testing)
6. Click "Connect" → "Connect your application"
7. Copy the connection string and replace `<username>`, `<password>`, and add `/elderlink` at the end

---

### 2. Mobile App — Backend URL (API host)

The mobile app **does not** use a single hard-coded `baseUrl` in source anymore. It uses:

- **Defaults:** host `192.168.137.1`, port `5000` (typical Windows mobile-hotspot gateway to the PC). Defined in `mobile/lib/services/api_service.dart` via `MOBILE_API_HOST` / `MOBILE_API_PORT` compile-time overrides.
- **Runtime:** host and port are saved with **SharedPreferences** after you set them in the app (**Backend / connection settings** screen — `mobile/lib/screens/backend_settings_screen.dart`).

**Options:**

1. **In the app (recommended on a physical device):** open staff settings → backend / API settings → enter your PC’s LAN IPv4 and port `5000` → save and test.
2. **At build/run time:**  
   `flutter run --dart-define=MOBILE_API_HOST=192.168.1.50 --dart-define=MOBILE_API_PORT=5000`
3. **Android emulator:** PC loopback is usually `10.0.2.2` (not the LAN IP).

---

### 3. Watch App — Backend URL (API host)

Same pattern as mobile, with **`WATCH_API_HOST`** / **`WATCH_API_PORT`** in `watch/lib/services/api_service.dart`. Defaults match mobile (`192.168.137.1:5000`). Persisted keys: watch Settings screen.

**Examples:**

```bash
flutter run --dart-define=WATCH_API_HOST=192.168.1.50 --dart-define=WATCH_API_PORT=5000
```

---

## Installation Steps

1. **Backend:**
   ```bash
   cd backend
   npm install
   # Create .env file with your MongoDB connection string
   node index.js
   ```

2. **Mobile App:**
   ```bash
   cd mobile
   flutter pub get
   flutter run -d chrome
   ```
   For web, use a fixed port so login persists: `.\run_web.ps1` or `flutter run -d chrome --web-port 55000`.

3. **Watch App:**
   ```bash
   cd watch
   flutter pub get
   flutter run -d chrome
   ```

---

## Important Notes

- All devices must be on the **same Wi-Fi network** (or hotspot from the PC running the API).
- Backend must be listening on `0.0.0.0` (or your LAN interface) so phones/watches can reach it; open **firewall TCP port 5000** on the PC if needed.
- If the PC’s IP changes, update **mobile** and **watch** saved host in Settings (or rebuild with new `--dart-define` values).
- MongoDB Atlas cluster must not be paused.

---

## Testing

1. Test backend connection:
   ```bash
   cd backend
   node test-connection.js
   ```

2. Test backend API: open `http://localhost:5000/api/readings` (should return JSON, often `[]`).

3. If apps can't connect: confirm backend is running, correct host/port in app settings, same network, and firewall.

---

For more detail, see [SETUP_INSTRUCTIONS.md](SETUP_INSTRUCTIONS.md).
