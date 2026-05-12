# TogetherIRL
CCNY Senior Design Project
# TogetherIRL - TableTalk Setup Guide

## Overview
This guide explains how to set up and test the TableTalk audio feature locally.

TableTalk currently uses:
- Flutter frontend
- FastAPI signaling backend
- LiveKit for real-time audio communication

---

# 1. Clone and Checkout Correct Branch

Clone the repo:

```bash
git clone <repo-url>
```

Go into project:

```bash
cd TogetherIRL
```

Switch to the audio branch:

```bash
git checkout audio
git pull
```

---

# 2. Install Required Software

Make sure you have:

- Git
- Flutter SDK
- Android Studio
- Android Emulator
- Python 3.x
- VS Code (optional)

Check installations:

```bash
flutter --version
py --version
```

---

# 3. Flutter Setup

From project root:

```bash
flutter pub get
```

If the Android folder is missing:

```bash
flutter create --platforms=android .
```

Check devices:

```bash
flutter devices
```

---

# 4. Android Permissions

Open:

```bash
android/app/src/main/AndroidManifest.xml
```

Make sure these permissions exist at the top:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

Example:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />

    <application
        ...
```

Without microphone permission, TableTalk audio will fail.

---

# 5. Python Backend Setup

Go into signaling folder:

```bash
cd signaling
```

Install dependencies:

```bash
py -m pip install -r requirements.txt
```

---

# 6. LiveKit Environment Variables

Inside the `signaling` folder, create a file called:

```bash
.env
```

Paste the LiveKit credentials provided privately by the team:

```env
LIVEKIT_URL=wss://your-livekit-project.livekit.cloud
LIVEKIT_API_KEY=your_api_key
LIVEKIT_API_SECRET=your_api_secret
```

IMPORTANT:
- Do NOT commit this file.
- Do NOT upload this to GitHub.
- Share credentials privately only.

---

# 7. Run Backend

Still inside `signaling`:

```bash
py -m uvicorn main:socket_app --host 0.0.0.0 --port 8001 --reload
```

Expected output:

```bash
Uvicorn running on http://0.0.0.0:8001
Application startup complete
```

Leave this terminal running.

---

# 8. Run Frontend

Open a NEW terminal.

Go to project root:

```bash
cd TogetherIRL
```

Run:

```bash
flutter run
```

Or choose a specific emulator:

```bash
flutter run -d emulator-5554
```

---

# 9. Two Emulator Testing

For testing multiple users locally:

Launch emulator 1:

```bash
flutter emulators --launch Medium_Phone
```

Launch emulator 2:

```bash
flutter emulators --launch Pixel_10_Pro_Fold
```

Check devices:

```bash
flutter devices
```

Example output:

```bash
emulator-5554
emulator-5556
```

Run app on emulator 1:

```bash
flutter run -d emulator-5554
```

Open NEW terminal.

Run app on emulator 2:

```bash
flutter run -d emulator-5556 --no-pub
```

---

# 10. TableTalk Testing Steps

Once both emulators are running:

### Test Join
- Open TableTalk tab
- Press Join on emulator 1
- Enter username
- Press Join on emulator 2
- Enter different username

Expected:
- both connect successfully
- live participant count updates

---

### Test Leave
Press Leave on one emulator.

Expected:
- other emulator updates immediately
- participant count decreases

---

### Test Foreground / Background
Move participants between:
- Foreground
- Background

Expected:
- UI updates correctly
- participant grouping changes

---

### Test Mute
Press mute/unmute buttons.

Expected:
- participant audio subscription changes

---

# 11. Current Feature Status

## Working
✅ LiveKit room connection  
✅ FastAPI token backend  
✅ username-based joining  
✅ real-time participant syncing  
✅ join/leave updates  
✅ foreground/background grouping UI  
✅ mute/unmute logic  
✅ two-user local testing  

---

## Not Fully Implemented Yet
⚠ true per-user volume scaling  
⚠ partial background volume reduction  
⚠ spatial audio positioning  
⚠ persistent user identities  

Reason:
Current Flutter LiveKit SDK does not expose easy remote participant volume control.

Current sliders are primarily UI/state logic.

---

# 12. Real Phone Testing

For Android emulators, backend token URL should be:

```dart
http://10.0.2.2:8001/token
```

This works because emulator maps `10.0.2.2` to your computer.

---

For REAL phones:

Replace:

```dart
http://10.0.2.2:8001/token
```

with:

```dart
http://YOUR_COMPUTER_IP:8001/token
```

Example:

```dart
http://192.168.1.25:8001/token
```

Find your computer IP:

Windows:

```bash
ipconfig
```

Look for:

```bash
IPv4 Address
```

Phone requirements:
- same Wi-Fi network as laptop
- backend running on laptop
- firewall allows port 8001

---

# 13. Troubleshooting

## Microphone permission denied

Fix:
Settings → App Permissions → Microphone → Allow

---

## Missing LiveKit URL or token

Cause:
`.env` missing or incorrect

Fix:
Check:

```env
LIVEKIT_URL
LIVEKIT_API_KEY
LIVEKIT_API_SECRET
```

Restart backend.

---

## Emulator cannot reach backend

Error example:

```bash
Network is unreachable
```

Fix:
Restart emulator

or:

```bash
adb -s emulator-5554 emu kill
```

Then relaunch.

---

## flutter not recognized

Fix:
Install Flutter SDK and add to PATH

Check:

```bash
flutter --version
```

---

## py not recognized

Fix:
Install Python with "Add Python to PATH"

Check:

```bash
py --version
```

---

# 14. Security Note

Never commit:

```bash
.env
```

Only commit:

```bash
.env.example
```

Example safe file:

```env
LIVEKIT_URL=replace_me
LIVEKIT_API_KEY=replace_me
LIVEKIT_API_SECRET=replace_me
```

---

# Quick Start Summary

Backend:

```bash
cd signaling
py -m pip install -r requirements.txt
py -m uvicorn main:socket_app --host 0.0.0.0 --port 8001 --reload
```

Frontend:

```bash
flutter pub get
flutter run
```

Two-device test:

```bash
flutter run -d emulator-5554
flutter run -d emulator-5556 --no-pub
```