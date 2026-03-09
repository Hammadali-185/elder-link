# How to Run Mobile App

## Quick Start

### Option 1: Use the Run Script (Recommended)
```powershell
cd D:\Users\HP\projects\oldage\mobile
.\run_web.ps1
```

This runs the app on a **fixed port (55000)** so your login data persists across restarts.

### Option 2: Manual Command
```powershell
cd D:\Users\HP\projects\oldage\mobile
flutter run -d chrome --web-port 55000
```

## Testing Data Storage

### 1. Test Login Persistence
1. Run the app using the script above
2. Click "Welcome" → Select "Staff" → Click "Sign Up"
3. Fill in:
   - Name: Your name
   - Username: testuser
   - Password: test123
4. Click "Sign Up"
5. You should see "Account created successfully!" and be logged in
6. **Close the browser tab completely**
7. **Run the app again** (using the same script)
8. Click "Welcome" → Select "Staff" → Click "Log In"
9. Enter the same username and password
10. **It should log you in!** ✅

### 2. Check Browser Storage (Advanced)
To verify data is actually stored:

1. Open Chrome DevTools (F12)
2. Go to **Application** tab
3. Expand **Local Storage** → Click on your app's URL (e.g., `http://localhost:55000`)
4. You should see keys like:
   - `flutter.staff_name`
   - `flutter.staff_username`
   - `flutter.staff_password`
   - `flutter.staff_logged_in`

### 3. Test Watch Data Display
1. Make sure backend is running: `cd backend && node index.js`
2. Open watch app in another browser tab
3. Fill in "My Info" on watch (Name, Age, Gender, Room Number)
4. Send a panic alert or health reading from watch
5. Check mobile app:
   - **Dashboard** → Should show reading with person name
   - **Alerts** → Should show alert with elder name
   - **Elders** → Should show watch user
   - **Medicines** → Should show watch user in dropdown

## Troubleshooting

### Data Not Persisting?
- **Make sure you're using the fixed port (55000)**
- Don't use `flutter run -d chrome` without `--web-port`
- Clear browser cache if needed: Chrome Settings → Privacy → Clear browsing data

### Backend Not Connecting?
- Make sure backend is running: `cd backend && node index.js`
- Check backend URL in `mobile/lib/services/api_service.dart`
- Default: `http://192.168.100.112:5000/api`
- Update if your IP address changed

### Can't See Elders/Medicines?
- Make sure backend server is running
- Check browser console (F12) for errors
- Verify MongoDB is connected (check backend terminal)

## Hot Reload Commands

While the app is running:
- Press `r` → Hot reload (fast, keeps state)
- Press `R` → Hot restart (slower, resets state)
- Press `q` → Quit
