# Phone Call Setup Guide - Step by Step Instructions

Use this guide while on a call to help them set up the ElderLink application.

---

## PRE-CALL CHECKLIST (Tell them to have ready)

- [ ] Computer with internet connection
- [ ] Node.js installed (check: open terminal/command prompt, type `node --version`)
- [ ] Flutter installed (check: open terminal, type `flutter --version`)
- [ ] Text editor (VS Code, Notepad++, or any text editor)
- [ ] MongoDB Atlas account (we'll create this together)

---

## STEP 1: Extract the Zip File

**Say:** "First, let's extract the zip file you received."

1. Right-click the zip file
2. Choose "Extract All" or "Extract Here"
3. Note the folder location (e.g., `C:\Users\YourName\Downloads\oldage`)

**Wait for them to confirm it's extracted.**

---

## STEP 2: Set Up MongoDB Atlas Account

**Say:** "Now we need to create a free MongoDB database. This is where all the data will be stored."

### 2.1 Create Account
1. Go to: https://www.mongodb.com/cloud/atlas
2. Click "Try Free" or "Sign Up"
3. Fill in email, password, and create account
4. Verify email if needed

**Wait for them to complete signup.**

### 2.2 Create Cluster
1. After login, click "Build a Database"
2. Choose "M0 FREE" (Free tier)
3. Select a cloud provider (AWS, Google Cloud, or Azure - doesn't matter)
4. Select a region closest to them
5. Click "Create" (takes 1-3 minutes)

**Say:** "This will take a minute or two. Let me know when it says 'Your cluster is ready'."

### 2.3 Create Database User
1. Click "Database Access" in left menu
2. Click "Add New Database User"
3. Choose "Password" authentication
4. Enter a username (e.g., `elderlink_user`)
5. Click "Autogenerate Secure Password" OR create your own password
6. **IMPORTANT:** Copy the password and save it somewhere safe!
7. Set privileges to "Atlas admin"
8. Click "Add User"

**Say:** "Did you save the username and password? We'll need it in a moment."

### 2.4 Whitelist IP Address
1. Click "Network Access" in left menu
2. Click "Add IP Address"
3. Click "Allow Access from Anywhere" (for development/testing)
4. Click "Confirm"

**Say:** "This allows the app to connect to the database from anywhere."

### 2.5 Get Connection String
1. Click "Database" in left menu
2. Click "Connect" button on your cluster
3. Choose "Connect your application"
4. Copy the connection string (looks like: `mongodb+srv://cluster0.xxxxx.mongodb.net/`)
5. **IMPORTANT:** The connection string has `<username>` and `<password>` placeholders

**Say:** "Now we need to replace those placeholders with your actual username and password."

---

## STEP 3: Configure Backend

**Say:** "Now let's set up the backend server that connects to the database."

### 3.1 Navigate to Backend Folder
1. Open terminal/command prompt
2. Navigate to the extracted folder:
   ```bash
   cd path\to\oldage\backend
   ```
   (Replace `path\to\oldage` with actual path)

**Say:** "Tell me when you're in the backend folder. You should see files like `index.js` and `package.json`."

### 3.2 Install Dependencies
**Say:** "Now we'll install the required packages."

```bash
npm install
```

**Wait for it to finish (may take 1-2 minutes).**

### 3.3 Create .env File
**Say:** "Now we need to create a configuration file with your database connection."

1. In the `backend` folder, create a new file called `.env`
   - Right-click in folder → New → Text Document
   - Name it exactly: `.env` (including the dot at the start)
   - If Windows asks about the extension, click "Yes"

2. Open `.env` in a text editor

3. Paste this template:
   ```
   MONGO_URI=mongodb+srv://USERNAME:PASSWORD@CLUSTER.mongodb.net/elderlink?retryWrites=true&w=majority
   PORT=5000
   ```

4. **Replace the placeholders:**
   - Replace `USERNAME` with the database username they created
   - Replace `PASSWORD` with the database password (if password has special characters, they may need to URL-encode them)
   - Replace `CLUSTER` with their actual cluster name from the connection string
   - Keep `/elderlink` at the end

**Example:**
```
MONGO_URI=mongodb+srv://elderlink_user:MyPass123@cluster0.abc123.mongodb.net/elderlink?retryWrites=true&w=majority
PORT=5000
```

**Say:** "Double-check that there are no spaces around the `=` sign and that the password is correct."

### 3.4 Test Connection
**Say:** "Let's test if the connection works."

```bash
node test-connection.js
```

**Expected output:** `✅ MongoDB connected successfully!`

**If error:**
- Check username/password are correct
- Check connection string format
- Make sure IP is whitelisted
- Check cluster is not paused

**Say:** "Great! The database connection works. Now let's start the server."

### 3.5 Start Backend Server
```bash
node index.js
```

**Expected output:**
```
✅ MongoDB connected successfully
✅ Server running on port 5000
✅ Ready to accept requests
```

**Say:** "Perfect! The backend is running. Keep this terminal window open. Now let's set up the mobile app."

---

## STEP 4: Find Computer's IP Address

**Say:** "The mobile and watch apps need to know where your backend server is. We need your computer's IP address."

### Windows:
1. Open Command Prompt
2. Type: `ipconfig`
3. Look for "IPv4 Address" under your active network adapter
4. It will look like: `192.168.1.100` or `192.168.100.112`
5. **Write this down!**

### Mac:
1. Open Terminal
2. Type: `ifconfig | grep "inet "`
3. Look for IP starting with `192.168.` or `10.`
4. **Write this down!**

### Linux:
1. Open Terminal
2. Type: `ip addr` or `hostname -I`
3. Look for IP starting with `192.168.` or `10.`
4. **Write this down!**

**Say:** "What IP address did you get? It should start with 192.168 or 10."

---

## STEP 5: Configure Mobile App

**Say:** "Now let's update the mobile app to connect to your backend."

### 5.1 Open API Service File
1. Navigate to: `mobile/lib/services/`
2. Open `api_service.dart` in a text editor

### 5.2 Update IP Address
1. Find line 8 (should say: `static const String baseUrl = 'http://192.168.100.112:5000/api';`)
2. Replace `192.168.100.112` with their IP address
3. Keep `:5000/api` at the end

**Example:**
```dart
static const String baseUrl = 'http://192.168.1.100:5000/api';
```

**Say:** "Make sure the IP address matches what we found earlier, and the port is 5000."

### 5.3 Install Dependencies
1. Open terminal in the `mobile` folder
2. Run:
   ```bash
   flutter pub get
   ```

**Wait for it to finish.**

### 5.4 Run Mobile App
**Say:** "Now let's run the mobile app."

```bash
flutter run -d chrome
```

**Or use the PowerShell script:**
```powershell
.\run_web.ps1
```

**Say:** "The app should open in Chrome. You should see a login/signup screen."

---

## STEP 6: Configure Watch App

**Say:** "Now let's do the same for the watch app."

### 6.1 Open API Service File
1. Navigate to: `watch/lib/services/`
2. Open `api_service.dart` in a text editor

### 6.2 Update IP Address
1. Find line 8 (should say: `static const String baseUrl = 'http://192.168.100.112:5000/api';`)
2. Replace `192.168.100.112` with the SAME IP address as mobile app
3. Keep `:5000/api` at the end

**Example:**
```dart
static const String baseUrl = 'http://192.168.1.100:5000/api';
```

**Say:** "This should be the exact same IP as the mobile app."

### 6.3 Install Dependencies
1. Open terminal in the `watch` folder
2. Run:
   ```bash
   flutter pub get
   ```

**Wait for it to finish.**

### 6.4 Run Watch App
**Say:** "Now let's run the watch app."

```bash
flutter run -d chrome
```

**Or use the PowerShell script:**
```powershell
.\run_web.ps1
```

**Say:** "The watch app should open in a new Chrome window. You should see a circular home screen."

---

## STEP 7: Test Everything

**Say:** "Let's test if everything is working together."

### 7.1 Test Mobile App
1. In mobile app, create an account (sign up)
2. Login with the account
3. You should see the dashboard

**Say:** "Can you see the dashboard? If yes, the mobile app is connected to the backend."

### 7.2 Test Watch App
1. In watch app, go to "My Info" (person icon at bottom)
2. Enter name, age, room number, etc.
3. Click "Save"

**Say:** "Did it save? If yes, the watch app is connected."

### 7.3 Test Data Flow
1. In watch app, go to "Health Monitoring" (heart icon)
2. Click "MEASURE BP" button
3. Wait for reading to complete
4. Go back to mobile app dashboard
5. Check if the reading appears

**Say:** "Can you see the health reading in the mobile app dashboard? If yes, everything is working!"

---

## COMMON ISSUES & SOLUTIONS

### Issue: "MongoDB connection failed"
**Solution:**
- Check username/password in `.env` file
- Verify connection string format
- Make sure IP is whitelisted in MongoDB Atlas
- Check cluster is not paused

### Issue: "Cannot connect to backend" in apps
**Solution:**
- Verify backend is running (check terminal)
- Check IP address is correct in both apps
- Ensure all devices are on same Wi-Fi network
- Try accessing `http://YOUR_IP:5000/api/readings` in browser

### Issue: "IP address changed"
**Solution:**
- Find new IP address (step 4)
- Update both `api_service.dart` files
- Restart both apps

### Issue: "Port 5000 already in use"
**Solution:**
- Change PORT in `backend/.env` to another number (e.g., 5001)
- Update `baseUrl` in both apps to use new port

---

## QUICK REFERENCE CHECKLIST

**Backend:**
- [ ] MongoDB Atlas account created
- [ ] Cluster created and running
- [ ] Database user created (username + password saved)
- [ ] IP whitelisted
- [ ] Connection string copied
- [ ] `.env` file created with correct connection string
- [ ] `npm install` completed
- [ ] `node test-connection.js` shows success
- [ ] `node index.js` running successfully

**Mobile App:**
- [ ] IP address found and written down
- [ ] `api_service.dart` updated with correct IP
- [ ] `flutter pub get` completed
- [ ] App running in browser
- [ ] Can sign up and login

**Watch App:**
- [ ] `api_service.dart` updated with same IP as mobile
- [ ] `flutter pub get` completed
- [ ] App running in browser
- [ ] Can save user info

**Testing:**
- [ ] Mobile app shows dashboard
- [ ] Watch app can save data
- [ ] Data from watch appears in mobile app
- [ ] All three apps working together

---

## END OF CALL NOTES

**Remind them:**
1. Keep backend server running (`node index.js` terminal must stay open)
2. If IP address changes, update both apps
3. MongoDB Atlas free tier has limitations (512MB storage)
4. All devices must be on same Wi-Fi network
5. For production, consider using a fixed IP or domain name

**Say:** "Everything should be working now! If you have any issues later, check the troubleshooting section or contact me."

---

## EMERGENCY TROUBLESHOOTING

**If nothing works:**
1. Stop everything (close all terminals)
2. Check backend: `cd backend && node test-connection.js`
3. If backend fails → MongoDB connection issue
4. If backend works → Check IP addresses in apps
5. Restart backend: `node index.js`
6. Restart both apps

**Quick test:**
- Open browser: `http://localhost:5000/api/readings`
- Should show: `[]` (empty array)
- If this works, backend is fine
- If this fails, backend has issues
