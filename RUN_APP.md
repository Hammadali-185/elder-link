# How to run the app

Use **two separate terminals**. PowerShell does not support `&&`; use the commands below as-is.

## Terminal 1 – Backend

```powershell
cd D:\Users\HP\projects\oldage\backend
node index.js
```

Or from project root:

```powershell
cd backend
.\run.ps1
```

(Make sure `backend/.env` has a valid `MONGO_URI`. If MongoDB fails, the server will not start.)

## Terminal 2 – Frontend (mobile app)

```powershell
cd D:\Users\HP\projects\oldage\mobile
.\run_web.ps1
```

Then open **http://localhost:55000** in Chrome.

---

**First time or after pulling changes:** From the `mobile` folder run:

```powershell
flutter pub get
```

Then run the frontend as above.
