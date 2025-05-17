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

### ✅ Prerequisite

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
git clone https://github.com/yourusername/Nivaran..git
cd Nivaran.
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
5. Setup Cloudaninary:
   - Create a new account
   - Create a new cloudinary account
   - Create a new cloudinary upload preset
   - Make new file secrets.dart in lib 
   - Replace cloudinaryUploadPreset , cloudinaryCloudName values 

#### 3. Android Configuration

Edit android/build.gradle.kts and app/build.gradle.kts if needed. Already configured for Firebase.


## 📥 Download the App

You can download the app using the link below:

[Download Nivaran APK (v1.0.0)](https://github.com/Alexa88879/Nivaran./releases/download/v1.0.0/Nivaran.apk)

Or visit our [official website](https://versionhost-88b2d.web.app/) 

> To see the ppt visit the ppt folder

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

This project is protected by a **Custom License**.  
You may view and contribute to this repository, but **you may not copy, re-upload, or publish this app as your own.**

See the [LICENSE](./LICENSE) file for full terms.

---

## 🙌 Our Mission

> “Report Problems. Vote Truth. Empower Change.”

Help us build smarter cities by connecting people with their civic needs.

---

## 🔗 Useful Links

- 🔥 Flutter Docs
 (https://flutter.dev/docs)- 🎯 Firebase Docs
 (https://firebase.google.com/docs)- 🐞 Open Issues (https://github.com/yourusername/Nivaran_3.0/issues)


