# ElderLink Setup Instructions

This guide will help you set up the ElderLink application with your own MongoDB Atlas database.

## Prerequisites

- Node.js (v14 or higher)
- Flutter SDK (for mobile and watch apps)
- MongoDB Atlas account (free tier available)

---

## Step 1: Set Up MongoDB Atlas

1. **Create a MongoDB Atlas Account**
   - Go to https://www.mongodb.com/cloud/atlas
   - Sign up for a free account (M0 Free Tier)

2. **Create a Cluster**
   - Click "Build a Database"
   - Choose "M0 Free" tier
   - Select a cloud provider and region
   - Click "Create"

3. **Create Database User**
   - Go to "Database Access" in the left menu
   - Click "Add New Database User"
   - Choose "Password" authentication
   - Enter a username and password (save these!)
   - Set user privileges to "Atlas admin" or "Read and write to any database"
   - Click "Add User"

4. **Whitelist Your IP Address**
   - Go to "Network Access" in the left menu
   - Click "Add IP Address"
   - Click "Allow Access from Anywhere" (for development) or add your specific IP
   - Click "Confirm"

5. **Get Your Connection String**
   - Go to "Database" → "Connect"
   - Choose "Connect your application"
   - Copy the connection string (looks like: `mongodb+srv://<username>:<password>@cluster.mongodb.net/`)
   - Replace `<username>` and `<password>` with your database user credentials
   - Add your database name at the end (e.g., `elderlink`)

---

## Step 2: Configure Backend

1. **Navigate to Backend Directory**
   ```bash
   cd backend
   ```

2. **Install Dependencies**
   ```bash
   npm install
   ```

3. **Create Environment File**
   - Copy `.env.example` to `.env`:
     ```bash
     cp .env.example .env
     ```
   - Or create a new `.env` file manually

4. **Edit `.env` File**
   - Open `.env` in a text editor
   - Replace the `MONGO_URI` with your MongoDB Atlas connection string:
     ```
     MONGO_URI=mongodb+srv://yourusername:yourpassword@yourcluster.mongodb.net/elderlink?retryWrites=true&w=majority
     ```
   - Optionally change `PORT` if you want a different port (default: 5000)

5. **Test Connection**
   ```bash
   node test-connection.js
   ```
   - You should see: `✅ MongoDB connected successfully!`

6. **Start Backend Server**
   ```bash
   node index.js
   ```
   - You should see: `✅ MongoDB connected successfully` and `✅ Server running on port 5000`

---

## Step 3: Configure Mobile App

1. **Find Your Computer's IP Address**
   - **Windows**: Open Command Prompt and run `ipconfig`, look for "IPv4 Address"
   - **Mac/Linux**: Run `ifconfig` or `ip addr`, look for your local network IP
   - Example: `192.168.1.100` or `192.168.100.112`

2. **Update API URL in Mobile App**
   - Open `mobile/lib/services/api_service.dart`
   - Find the line: `static const String baseUrl = 'http://192.168.100.112:5000/api';`
   - Replace `192.168.100.112` with your computer's IP address
   - Make sure the port matches your backend port (default: 5000)

3. **Install Dependencies**
   ```bash
   cd mobile
   flutter pub get
   ```

4. **Run Mobile App**
   ```bash
   flutter run -d chrome
   ```
   - Or use the PowerShell script: `.\run_web.ps1`

---

## Step 4: Configure Watch App

1. **Update API URL in Watch App**
   - Open `watch/lib/services/api_service.dart`
   - Find the line: `static const String baseUrl = 'http://192.168.100.112:5000/api';`
   - Replace `192.168.100.112` with your computer's IP address (same as mobile app)
   - Make sure the port matches your backend port (default: 5000)

2. **Install Dependencies**
   ```bash
   cd watch
   flutter pub get
   ```

3. **Run Watch App**
   ```bash
   flutter run -d chrome
   ```
   - Or use the PowerShell script: `.\run_web.ps1`

---

## Step 5: Important Notes

### Network Requirements
- **All devices must be on the same Wi-Fi network** (mobile, watch, and backend server)
- The IP address in the apps must match the computer running the backend
- If your IP changes, update the `baseUrl` in both mobile and watch apps

### Port Configuration
- Backend default port: `5000`
- Mobile app port: `55000` (for web, fixed for data persistence)
- Watch app port: `55001` (for web, fixed for data persistence)

### Data Persistence
- Mobile and watch apps use fixed ports (55000, 55001) to preserve localStorage data
- Backend data is stored in MongoDB Atlas and persists across restarts

---

## Troubleshooting

### Backend Won't Connect to MongoDB
- Check your connection string in `.env`
- Verify username and password are correct
- Ensure your IP is whitelisted in MongoDB Atlas
- Check if your cluster is running (not paused)

### Apps Can't Connect to Backend
- Verify backend is running: `http://localhost:5000/api/readings`
- Check your computer's IP address hasn't changed
- Ensure all devices are on the same network
- Check firewall settings (port 5000 must be accessible)

### Connection String Format
Correct format:
```
mongodb+srv://username:password@cluster.mongodb.net/database-name?retryWrites=true&w=majority
```

Common mistakes:
- ❌ Forgetting to replace `<username>` and `<password>`
- ❌ Missing database name at the end
- ❌ Using wrong cluster URL
- ❌ Special characters in password not URL-encoded

---

## Quick Start Checklist

- [ ] MongoDB Atlas account created
- [ ] Database user created with username/password
- [ ] IP address whitelisted in MongoDB Atlas
- [ ] Connection string copied and configured in `backend/.env`
- [ ] Backend server running and connected to MongoDB
- [ ] Computer's IP address found
- [ ] Mobile app `api_service.dart` updated with correct IP
- [ ] Watch app `api_service.dart` updated with correct IP
- [ ] All apps tested and working

---

## Support

If you encounter issues:
1. Check the backend console for error messages
2. Verify MongoDB Atlas cluster is not paused
3. Test backend connection: `node backend/test-connection.js`
4. Check network connectivity between devices
5. Verify all IP addresses and ports are correct
