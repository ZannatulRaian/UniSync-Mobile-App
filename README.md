<p align="center">
  <h1 align="center">UniSync</h1>
  <p align="center">
    A Modern University Collaboration Platform
  </p>
</p>

---

# App Preview

<p align="center">
  <img src="screenshots/home.png" width="250"/>
  <img src="screenshots/events.png" width="250"/>
  <img src="screenshots/chat.png" width="250"/>
</p>

<p align="center">
  <i>Home Screen • Chat System • Events Dashboard</i>
</p>

---

# UniSync

**UniSync** is a mobile application designed to simplify communication, collaboration, and resource sharing within a university environment.  

It enables **students and faculty** to connect through announcements, events, messaging, and shared resources in a single unified platform.

The application is built using **Flutter** with **Supabase** as the backend.

---

# Features

### Authentication
- Secure user authentication
- Role-based access (Student / Faculty)
- University email validation

### Announcements
- Faculty can create and post announcements
- Students can view announcements in real-time

### Events
- Faculty can create university events
- Students can RSVP to events
- Event information displayed on dashboard

### Chat System
- Direct messaging between users
- Online presence indicators
- Realtime chat updates

### Resource Sharing
- Upload academic resources (PDF, files, etc.)
- Download resources shared by others
- Organized storage system

### User Profiles
- Profile management
- Department and semester information
- Avatar support

---

# Tech Stack

| Layer | Technology |
|-----|-----|
| Frontend | Flutter |
| Backend | Supabase |
| Database | PostgreSQL |
| Storage | Supabase Storage |
| Authentication | Supabase Auth |
| Realtime | Supabase Realtime |

---

# Project Structure

```
lib/
 ├── screens/
 ├── services/
 ├── models/
 ├── providers/
 ├── theme/
 └── main.dart

assets/
test/
android/
```

---

# Requirements

Before running the project make sure you install:

- Flutter 3.x
- Android Studio
- VS Code
- Node.js
- Supabase account

---

# Setup Guide

### 1. Clone the Repository

```
git clone https://github.com/ZannatulRaian/UniSync-Mobile-App.git
cd unisync
```

---

### 2. Install Dependencies

```
flutter pub get
```

---

### 3. Configure Supabase

Open:

```
lib/main.dart
```

Replace the following values:

```
url: 'YOUR_SUPABASE_URL',
anonKey: 'YOUR_SUPABASE_ANON_KEY',
```

Get them from:

```
Supabase Dashboard → Project Settings → API
```

---

### 4. Run the Application

Connect your Android device and run:

```
flutter run
```

---

# Build APK

To generate a release APK:

```
flutter build apk --release
```

APK location:

```
build/app/outputs/flutter-apk/app-release.apk
```

---

# User Roles

| Role | Permissions |
|----|----|
| Student | View announcements, RSVP events, upload/download resources, chat |
| Faculty | All student permissions + post announcements and create events |

---

# Security Improvements

This version includes multiple security fixes such as:

- Enforced HTTPS communication
- Role validation for restricted actions
- Database query protection
- Chat membership validation
- File storage access control
- Input validation improvements

---

# Troubleshooting

### Flutter not recognized
Restart terminal and verify:

```
flutter --version
```

### Device not detected
Run:

```
flutter devices
```

Enable **USB Debugging** on your Android phone.

### App cannot connect to backend
Verify the Supabase **URL** and **Anon Key** in `main.dart`.

---

# Contribution

Contributions are welcome.

Steps:

1. Fork the repository
2. Create a new branch
3. Make your changes
4. Submit a Pull Request

---

# License

This project is for **educational and academic purposes**.

---

<p align="center">
  Built with Flutter and Supabase
</p>
