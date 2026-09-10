# 📅 Smart Scheduler and Management System

A robust, hierarchical, and scalable **Timetable Management System** built for Universities/Colleges. It provides role-based access for different levels of faculty and students, allowing seamless scheduling, room allocation, and timetable viewing.

## 🚀 Tech Stack

### Frontend
- **Framework:** Flutter (Android, iOS, Web)
- **Language:** Dart
- **Key Packages:**
  - `excel`: Parsing Excel sheets for automatic timetable/user uploads.
  - `file_picker`: Selecting Excel files from the local filesystem.
  - `shared_preferences`: Local caching and session management.
  - `flutter_local_notifications`: Alerting students/faculty about upcoming lectures.

### Backend & Infrastructure
- **Database:** Firebase Cloud Firestore (NoSQL)
  - Features real-time syncing and dynamic structured collections.
- **Authentication:** Firebase Authentication
  - Role-based access control (Admin, HOS, VC, Faculty, Student).
- **Backend Scripts:** Node.js (`firebase-admin`)
  - Utilities for massive database resets and hierarchical seeding.

---

## 🏗️ Project Architecture & Database Schema

The system relies on a **Dynamic Hierarchical Structure** to map data accurately without hardcoding dropdowns or arrays:

1. **Schools**: Top level (e.g., *School of Engineering*, *School of Science*).
2. **Departments**: Nested under Schools (e.g., *CSE*, *ECE*).
   - *Self-Updating Hierarchy:* Each Department document contains a `structure` mapping `Years -> Divisions` (e.g., `SY -> [A, B, C]`). This is dynamically synchronized whenever an Admin uploads a new Timetable Excel file.
3. **Users**: Bound to specific roles (Admin, VC, HOS, Faculty).
4. **Rooms**: Automatically populated during timetable upload. Tracks real-time availability and current occupant.
5. **Timetable**: Core collection storing every lecture's time slot, subject, faculty, and room.

---

## ✨ Key Features

- **Role-Based Dashboards:**
  - **Admin:** Full control over users, timetable resets, and database state.
  - **VC (Vice Chancellor):** University-wide view of all Schools and Departments.
  - **HOS (Head of School):** Scoped view restricted to their specific School's Departments.
  - **Faculty/Student:** Personalized timetable viewing.
- **Smart Excel Uploads:** 
  - Upload a `.xlsx` timetable to automatically populate records.
  - *Auto-Sync*: The app dynamically extracts all unique rooms and hierarchical metadata (Years & Divisions) on the fly, eliminating manual database administration.
- **Real-Time Progress Indicators:** Visual feedback (loading spinners, snackbars) provided during heavy background operations.
- **Cascading Dropdowns:** Guaranteed valid data entry (selecting a Department dynamically filters the available Years, which in turn filters the Divisions).
- **Room Availability Tracking:** View which rooms are occupied or free at any given time.

---

## 🛠️ Setup & Operations

### 1. Prerequisites
- Flutter SDK (latest version)
- Node.js (for backend administration scripts)
- A Firebase project with Firestore and Authentication enabled

### 2. Firebase Configuration
Before running the application, you must link it to your own Firebase project:
1. Generate `google-services.json` from your Firebase Console for the Android app and place it in `android/app/google-services.json`.
2. Generate `GoogleService-Info.plist` for the iOS app and place it in `ios/Runner/GoogleService-Info.plist` (if building for iOS).
3. Generate a Firebase Service Account Key from your Firebase Console and save it as `serviceAccountKey.json` inside the `backend/` directory.

### 3. Running the App
```bash
flutter pub get
flutter run
```

### 4. Resetting the Database (Fresh Slate)
If you ever need to completely wipe the database (all users, timetables, and nested hierarchies) and start fresh:
1. Ensure your `serviceAccountKey.json` is correctly placed inside the `backend/` folder.
2. Run the Node.js reset script:
```bash
cd backend
npm install
node reset_and_seed.js
```
This initializes default schools, admin user, and basic rooms. From there, log into the Flutter app as `admin` to upload your timetable Excel files!
