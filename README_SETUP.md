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

### 2. Mobile App Configuration

**File:** `mobile/lib/services/api_service.dart`

**Line 8:** Change the IP address to your computer's IP:

```dart
static const String baseUrl = 'http://YOUR_COMPUTER_IP:5000/api';
```

**How to find your computer's IP:**
- **Windows:** Open Command Prompt, type `ipconfig`, look for "IPv4 Address"
- **Mac/Linux:** Open Terminal, type `ifconfig` or `ip addr`, look for your local network IP
- Example: `192.168.1.100` or `192.168.100.112`

---

### 3. Watch App Configuration

**File:** `watch/lib/services/api_service.dart`

**Line 8:** Change the IP address to your computer's IP (same as mobile app):

```dart
static const String baseUrl = 'http://YOUR_COMPUTER_IP:5000/api';
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
   # Update api_service.dart with your IP
   flutter run -d chrome
   ```

3. **Watch App:**
   ```bash
   cd watch
   flutter pub get
   # Update api_service.dart with your IP
   flutter run -d chrome
   ```

---

## Important Notes

- ✅ All devices must be on the **same Wi-Fi network**
- ✅ Backend must be running before starting mobile/watch apps
- ✅ If your computer's IP changes, update both mobile and watch apps
- ✅ MongoDB Atlas cluster must not be paused

---

## Testing

1. Test backend connection:
   ```bash
   cd backend
   node test-connection.js
   ```

2. Test backend API:
   Open browser: `http://localhost:5000/api/readings`
   Should return: `[]` (empty array)

3. If apps can't connect:
   - Check backend is running
   - Verify IP address is correct
   - Ensure all devices are on same network
   - Check firewall settings

---

For detailed instructions, see `SETUP_INSTRUCTIONS.md`
