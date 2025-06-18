# Nivaran - Civic Issue Reporting & Management App

[![Flutter Version](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)
[![Dart Version](https://img.shields.io/badge/Dart-3.x-blue.svg)](https://dart.dev)
[![License: Custom](https://img.shields.io/badge/License-Custom-blue.svg)](#license)

Nivaran is a Flutter-based mobile application designed to bridge the gap between citizens and local authorities by providing a platform for reporting, tracking, and resolving civic issues.

## Overview

Nivaran empowers citizens to report various local problems such as potholes, garbage dumping, street light outages, and more, directly from their mobile devices. These reports, enriched with details, images, and geo-location, are then accessible to concerned officials for timely acknowledgement and resolution. The app aims to foster transparency and efficiency in addressing public grievances.

## Features

### For Citizens (Public Users):
* **User Authentication:**
    * Sign up and log in using Email/Password.
    * Social login with Google.
    * Social login with Facebook.
    * Email verification.
* **Issue Reporting:**
    * Create detailed issue reports with title, description, and category.
    * Capture and attach multiple images to a report.
    * Automatically fetch and attach geo-location (latitude/longitude and address) to the report.
    * Select issue category (e.g., Road Maintenance, Waste Management, Water Supply).
* **Issue Tracking & Feed:**
    * View a live feed of issues reported by others.
    * Filter issues by category or status.
    * View detailed information for each issue, including images, location on a map, and current status.
    * Add comments to issues.
    * Receive real-time notifications on status updates for reported or followed issues.
* **Map View:**
    * Visualize reported issues on an interactive map.
* **Profile Management:**
    * View and update user profile information.
    * View history of reported issues.
* **Notifications:**
    * In-app notifications for issue updates, comments, etc.
    * Push notifications (via Firebase Cloud Messaging).

### For Officials:
* **Secure Authentication:**
    * Separate login and registration process for officials.
    * Password management and secure access.
* **Dashboard:**
    * View a comprehensive dashboard of all reported issues.
    * Filter and sort issues by category, status, priority, location, or date.
* **Issue Management:**
    * View detailed issue reports submitted by citizens.
    * Update the status of issues (e.g., "New," "Acknowledged," "In Progress," "Resolved," "Rejected").
    * Assign priority to issues.
    * Add internal comments or notes for issues.
* **Statistics & Reporting:**
    * View graphical statistics on issue types, resolution times, and regional distribution.
* **User Management (Potential):**
    * Manage official accounts and roles.

### Common Features:
* **Role-Based Access Control:** Different UIs and functionalities for citizens and officials.
* **Image Handling:** Image capture, selection from gallery, full-screen view, and uploading.
* **Location Services:** Accurate location fetching and display on maps.
* **Real-time Updates:** Firestore ensures data is synced in real-time across all users.
* **Offline Support (Potential):** Basic caching for viewing previously loaded data.
* **Update Checker:** Notifies users about new app versions.

## 📸 App Screenshots

Here’s an overview of the **Nivaran** app’s key screens and features:

| **Splash Screen** | **Public Dashboard** | **Officials Issue Dashboard** |
| --- | --- | --- |
| ![](assets/icon/1.jpg) | ![](assets/icon/2.jpg) | ![](assets/icon/3.jpg) |

| **Officials Statistics 1** | **Officials Statistics 2** | **Officials Alerts** |
| --- | --- | --- |
| ![](assets/icon/4-1.jpg) | ![](assets/icon/4-2.jpg) | ![](assets/icon/5.jpg) |

| **Officials Profile 1** | **Officials Profile 2** | **User Issue Dashboard** |
| --- | --- | --- |
| ![](assets/icon/6-1.jpg) | ![](assets/icon/6-2.jpg) | ![](assets/icon/7-1.jpg) |

| **AI Prediction** | **User Captures Image** | **Report an Issue** |
| --- | --- | --- |
| ![](assets/icon/7-2.jpg) | ![](assets/icon/8-1.jpg) | ![](assets/icon/8-2.jpg) |

| **Voice Reporting on Issue** | **Map View** | **Map Zoom & Marker** |
| --- | --- | --- |
| ![](assets/icon/8-3.jpg) | ![](assets/icon/9-1.jpg) | ![](assets/icon/9-2.jpg) |

| **User Alerts** | **User Profile** | **Comments** |
| --- | --- | --- |
| ![](assets/icon/10.jpg) | ![](assets/icon/11.jpg) | ![](assets/icon/12.jpg) |

## Tech Stack

* **Frontend:** Flutter
* **Backend & Database:** Firebase
    * **Authentication:** Firebase Auth (Email/Password, Google, Facebook)
    * **Database:** Cloud Firestore (for storing user data, issues, comments, etc.)
    * **Storage:** Firebase Storage (for image uploads)
    * **Push Notifications:** Firebase Cloud Messaging (FCM)
* **State Management:** Provider
* **Mapping:** Google Maps Flutter
* **Location:** Geolocator, Geocoding
* **Image Handling:** Image Picker, Camera, Photo View, Image Cropper
* **HTTP Client:** `http` package
* **Local Notifications:** `flutter_local_notifications`
* **Charting:** `fl_chart` (for official statistics)
* **Other Key Packages:**
    * `intl` (Internationalization & Date Formatting)
    * `url_launcher` (Opening external links)
    * `package_info_plus` (App version checking)
    * `path_provider` (File system paths)
    * `permission_handler` (Runtime permissions)
    * `connectivity_plus` (Network status)
    * `flutter_dotenv` (Environment variable management)

## Project Structure

The project follows a standard Flutter project structure:

nivaran/                                                                                                                                                                      
├── android/                      # Android specific files                                                                                                                    
├── ios/                          # iOS specific files                                                                                                                        
├── lib/                                                                                                                                                                      
│   ├── common/                   # Common widgets/utils                                                                                                                      
│   ├── main.dart                 # App entry point                                                                                                                           
│   ├── models/                   # Data models (User, Issue, Comment, etc.)                                                                                                  
│   ├── screens/                  # UI screens categorized by feature                                                                                                         
│   │   ├── auth/
│   │   ├── feed/                                                                                                                                                             
│   │   ├── map/                                                                                                                                                             
│   │   ├── notifications/                                                                                                                                                    
│   │   ├── official/                                                                                                                                                         
│   │   ├── profile/                                                                                                                                                          
│   │   └── report/                                                                                                                                                           
│   ├── services/             # Backend services (Auth, Firestore, Storage, Location, etc.)                                                                                   
│   ├── utils/                    # Utility functions (Validators, Update Checker)                                                                                            
│   └── widgets/                  # Reusable custom widgets                                                                                                                   
├── assets/                       # App assets (images, fonts - if any)                                                                                                       
├── test/                         # Unit and widget tests                                                                                                                     
├── pubspec.yaml                  # Project dependencies and metadata                                                                                                         
└── README.md                     # This file                                                                                                                                  

## Getting Started

### Prerequisites

* Flutter SDK (version 3.x recommended)
* Dart SDK (version 3.x recommended)
* An IDE like Android Studio or VS Code with Flutter plugins.
* Firebase account and a new Firebase project.

### Setup

1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/your-username/nivaran.git](https://github.com/your-username/nivaran.git) # Replace with your repo URL
    cd nivaran
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Firebase Configuration:**
    * Set up a Firebase project at [console.firebase.google.com](https://console.firebase.google.com/).
    * Add an Android app and an iOS app to your Firebase project.
    * **Android:**
        * Download the `google-services.json` file from your Firebase project settings.
        * Place it in the `android/app/` directory.
        * Ensure your Android package name in `android/app/build.gradle.kts` matches the one in Firebase.
    * **iOS:**
        * Download the `GoogleService-Info.plist` file from your Firebase project settings.
        * Open the `ios/Runner.xcworkspace` in Xcode and add this file to the `Runner` target.
        * Ensure your iOS bundle ID in Xcode matches the one in Firebase.
    * **Enable Firebase Services:**
        * **Authentication:** Enable Email/Password, Google, and Facebook sign-in methods in the Firebase console. For Facebook login, additional setup on the Facebook Developer portal is required.
        * **Cloud Firestore:** Create a Firestore database. Set up appropriate security rules.
        * **Firebase Storage:** Set up Firebase Storage. Configure security rules (e.g., allow authenticated users to write to specific paths).
        * **Firebase Cloud Messaging (FCM):** No specific enablement needed in console for basic setup, but ensure API is enabled if using legacy protocols.

4.  **Google Maps API Key:**
    * Obtain a Google Maps API key from the [Google Cloud Console](https://console.cloud.google.com/apis/library/maps-android-sdk-backend.googleapis.com). Ensure "Maps SDK for Android" and "Maps SDK for iOS" are enabled.
    * **Android:** Add the API key to `android/app/src/main/AndroidManifest.xml`:
        ```xml
        <meta-data android:name="com.google.android.geo.API_KEY"
                   android:value="YOUR_ANDROID_MAPS_API_KEY"/>
        ```
    * **iOS:** Add the API key to `ios/Runner/AppDelegate.swift`:
        ```swift
        import UIKit
        import Flutter
        import GoogleMaps // Add this import

        @UIApplicationMain
        @objc class AppDelegate: FlutterAppDelegate {
          override func application(
            _ application: UIApplication,
            didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
          ) -> Bool {
            GMSServices.provideAPIKey("YOUR_IOS_MAPS_API_KEY") // Add this line
            GeneratedPluginRegistrant.register(with: self)
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
          }
        }
        ```

5.  **Environment Variables (Optional but Recommended):**
    * If using `flutter_dotenv`, create a `.env` file in the root of your project:
        ```
        # Example .env file
        # API_KEY_EXAMPLE=your_api_key_here
        ```
    * Add `.env` to your `.gitignore` file.
    * Load these in your `main.dart` or service files.

6.  **Run the app:**
    ```bash
    flutter run
    ```
    Or use your IDE's run button.

## Contributing

Contributions are welcome! If you'd like to contribute, please follow these steps:

1.  Fork the repository.
2.  Create a new branch (`git checkout -b feature/your-feature-name`).
3.  Make your changes.
4.  Commit your changes (`git commit -m 'Add some feature'`).
5.  Push to the branch (`git push origin feature/your-feature-name`).
6.  Open a Pull Request.

Please make sure to update tests as appropriate.

## 👥 Contributors

| [<img src="https://github.com/ekank123.png" width="100px;"/><br />@ekank123](https://github.com/ekank123) | [<img src="https://github.com/vaibhav2195.png" width="100px;"/><br />@vaibhav2195](https://github.com/vaibhav2195) | [<img src="https://github.com/Deva3664.png" width="100px;"/><br />@Deva3664](https://github.com/Deva3664) | [<img src="https://github.com/Alexa88879.png" width="100px;"/><br />@Alexa88879](https://github.com/Alexa88879) |
| :---: | :---: | :---: | :---: |

## 📄 License

This project is licensed under the terms specified in the [LICENSE](LICENSE.md) file. Please refer to the `LICENSE.md` file in the root of the repository for full details.



## Acknowledgements

* Flutter team for the amazing framework.
* Firebase team for the robust backend services.
* Contributors to all the open-source packages used.

---
