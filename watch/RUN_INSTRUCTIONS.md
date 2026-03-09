# How to Run Watch App

## Quick Start

### Use the Run Script (Recommended)
```powershell
cd D:\Users\HP\projects\oldage\watch
.\run_web.ps1
```

This runs the watch app on a **fixed port (55001)** so your saved info persists across restarts.

### Manual Command
```powershell
cd D:\Users\HP\projects\oldage\watch
flutter run -d chrome --web-port 55001
```

## Testing Data Storage

### 1. Test Info Persistence
1. Run the app using the script above
2. Go to "My Info" screen (person icon)
3. Fill in:
   - Name: Your name (e.g., "John Doe")
   - Gender: Select Male/Female/Other
   - Age: Your age (e.g., "75")
   - Room Number: Your room (e.g., "101")
   - Disease: Optional
4. Click "Save"
5. **Close the browser tab completely**
6. **Run the app again** (using the same script)
7. Go to "My Info" screen again
8. **Your data should still be there!** ✅

### 2. Test Data Sent to MongoDB
1. Fill in "My Info" and save
2. Send a panic alert or health reading
3. Check mobile app:
   - **Dashboard** → Should show reading with your name
   - **Alerts** → Should show alert with your name
   - **Elders** → Should show you in the list
   - **Medicines** → Should show you in the dropdown

## Important Notes

- **Always use `--web-port 55001`** (or the run script) so data persists
- Don't use `flutter run -d chrome` without the port flag (data won't persist)
- Make sure backend is running: `cd backend && node index.js`
- Watch app uses port **55001** (different from mobile app's 55000)

## Hot Reload Commands

While the app is running:
- Press `r` → Hot reload (fast, keeps state)
- Press `R` → Hot restart (slower, resets state)
- Press `q` → Quit
