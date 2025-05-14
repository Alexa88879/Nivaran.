# 🚨 Nivaran  — Civic Issue Reporting App

<div align="center">
  <img src="assets/icon/app_logo.png" alt="Nivaran Logo" width="150" />
</div>

**Nivaran** is a community-powered mobile app to report, verify, and track civic issues — making neighborhoods better through collective action.

---

## 📱 App Features

- 📸 **Report Civic Issues** with image, location & description
- 📍 Live issue tracking
- 🧠 Community verification (upvote true reports)
- 🔔 Real-time notifications via Firebase
- 📊 Issue categories: Road, Light, Safety, Waste, etc.
- 🌙 Dark mode + modern Flutter UI

---

## 🚀 Quick Start Guide (for Developers)

### ✅ Prerequisites

Make sure you have:

- Flutter SDK [Install → https://docs.flutter.dev/get-started/install]
- Android Studio OR VS Code with Dart & Flutter plugins
- Firebase account → [https://firebase.google.com/]
- Node.js & Firebase CLI (`npm install -g firebase-tools`)
- A connected Android emulator OR real device

---

### ⚙️ Step-by-Step Setup

#### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/Nivaran_3.0.git
cd Nivaran_3.0
flutter pub get
```

#### 2. Firebase Setup

1. Go to Firebase Console (https://console.firebase.google.com/)
2. Create a new project (e.g., `nivaran`)
3. Add Android app:
   - Package name: com.example.modern_auth_app
   - Register app, download google-services.json
   - Replace it at:  
     android/app/google-services.json
4. Enable:
   - Email/Password Authentication
   - Firebase Firestore
   - Firebase Storage
   - Cloud Messaging (for notifications)

#### 3. Android Configuration

Edit android/build.gradle.kts and app/build.gradle.kts if needed. Already configured for Firebase.

#### 4. Run the App
Download the app by using apk release section in github or by visiting our website 

flutter run

> 🟢 The app will launch on your connected emulator/device.

---

## 🧠 App Folder Structure

Nivaran_3.0/
│
├── android/               # Android native files
├── assets/                # Images, icons
├── lib/                   # Main Flutter code
│   ├── screens/           # App screens
│   ├── widgets/           # Custom UI widgets
│   ├── services/          # Firebase logic, APIs
│   └── main.dart          # Entry point
├── pubspec.yaml           # Dependencies
└── README.md              # This file

---

## 💡 Common Issues & Fixes

| Issue | Solution |
|-------|----------|
| google-services.json missing | Ensure it's placed in android/app/ |
| Firebase errors | Recheck Firebase project setup and SHA-1 |
| Plugin not installed | Run flutter pub get again |
| App won’t start | Use physical device or enable emulator & USB debugging |


---

## 🔧 Tech Stack

| Layer        | Tool            |
|--------------|-----------------|
| UI           | Flutter         |
| Backend      | Firebase (Firestore, Auth) |
| Notifications| Firebase Cloud Messaging |
| Storage      | Cloudinary |

---

## 🤝 Contributing

Want to improve the app? Here's how:

# Fork → Clone → Create branch → Code → Push → PR
git checkout -b feature/amazing-feature

Please follow proper naming, write clean commits, and document your code.

---

## 📄 License

MIT License. Feel free to use, improve and share!

---

## 🙌 Our Mission

> “Report Problems. Vote Truth. Empower Change.”

Help us build smarter cities by connecting people with their civic needs.

---

## 🔗 Useful Links

- 🔥 Flutter Docs
 (https://flutter.dev/docs)- 🎯 Firebase Docs
 (https://firebase.google.com/docs)- 🐞 Open Issues (https://github.com/yourusername/Nivaran_3.0/issues)
