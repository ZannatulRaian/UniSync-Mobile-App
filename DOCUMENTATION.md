# UniSync — Technical Documentation

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Technology Stack](#2-technology-stack)
3. [Core Functionalities](#3-core-functionalities)
4. [Project Structure](#4-project-structure)
5. [Architecture & Data Flow](#5-architecture--data-flow)
6. [Data Models](#6-data-models)
7. [API & Service Documentation](#7-api--service-documentation)
8. [Database Schema](#8-database-schema)
9. [Offline-First Architecture](#9-offline-first-architecture)
10. [Push Notification System](#10-push-notification-system)
11. [Authentication & Role System](#11-authentication--role-system)
12. [Environment Configuration](#12-environment-configuration)
13. [Build & Deployment](#13-build--deployment)
14. [Row-Level Security Policies](#14-row-level-security-policies)
15. [Troubleshooting](#15-troubleshooting)

---

## 1. Project Overview

**UniSync** is a cross-platform mobile application (Flutter / Android) designed for university communities. It provides a single hub for students and faculty to communicate, stay informed about campus events, share academic resources, and coordinate in real time — even without an internet connection.

### Key Design Principles

- **Offline-First** — Every read-heavy action emits cached data before hitting the network. Write operations (messages, announcements, events, file uploads) are queued locally and replayed automatically when connectivity returns.
- **Role-Based Access** — Users are automatically assigned a `student` or `faculty` role at sign-up based on their institutional ID format. Role determines which create/delete actions are permitted at both the application and database level.
- **Real-Time Updates** — Supabase Realtime subscriptions propagate changes to all connected clients without requiring manual refresh.
- **University-Only Access** — Email validation enforces `.edu`, `.edu.bd`, `.ac.bd`, `.ac.uk`, and `.ac.in` domains at both sign-in and sign-up.

### Target Users

- University students
- Faculty / academic staff
- Campus organisations

---

## 2. Technology Stack

| Layer | Technology | Version |
|---|---|---|
| UI Framework | Flutter (Dart) | SDK ≥ 3.2.0 |
| State Management | Riverpod | `flutter_riverpod ^2.6.1` |
| Backend / Auth / Realtime | Supabase | `supabase_flutter ^2.5.0` |
| Local Database (offline cache) | Isar | `isar ^3.1.0+1` |
| Push Notifications | OneSignal | `onesignal_flutter ^5.2.5` |
| Firebase | Firebase Core + FCM | `firebase_core ^3.2.0` |
| Notification Edge Function | Supabase Edge Function (Deno / TypeScript) | — |
| Connectivity Detection | connectivity_plus | `^6.1.1` |
| Environment Variables | flutter_dotenv | `^5.1.0` |
| File Upload | file_picker, image_picker | `^8.3.7`, `^1.1.2` |
| UI Utilities | google_fonts, table_calendar, shimmer, cached_network_image, timeago | — |

---

## 3. Core Functionalities

### 3.1 Authentication

- Email/password sign-up and sign-in via Supabase Auth.
- University email domain enforcement (`.edu`, `.edu.bd`, `.ac.bd`, `.ac.uk`, `.ac.in`).
- Automatic role assignment (`student` / `faculty`) from institutional ID format at database level — enforced by trigger `trg_assign_role_from_id`.
- Persistent onboarding flag in `SharedPreferences` so sign-out routes to Login, not Onboarding.
- User profile cached locally for offline access.
- Password reset via Supabase email flow.

**Sign-up example**:
```dart
final user = await authService.signUp(
  name: "Jane Doe",
  email: "jane.doe@university.edu",
  password: "SecurePass123",
  department: "Computer Science",
  semester: "6",
  studentId: "31234567",   // starts with 3 → student role
);
```

**Sign-in example**:
```dart
final user = await authService.signIn(
  "jane.doe@university.edu",
  "SecurePass123",
);
```

---

### 3.2 Announcements

- Faculty can post announcements categorised as `Academic`, `Financial`, `General`, or `Club`.
- All authenticated users can read and bookmark announcements.
- Announcements are filtered by type on the client side.
- **Offline**: new announcements are queued as `IsarPendingAction` with `actionType = 'post_announcement'` and an optimistic local copy is inserted immediately.
- Push notification sent to all users (except the poster) on each new announcement.

```dart
// Stream all announcements
announcementService.getAnnouncements().listen((list) {
  print("${list.length} announcements loaded");
});

// Stream filtered by type
announcementService.getAnnouncements(type: "Academic").listen((list) {
  print("${list.length} academic announcements");
});

// Post an announcement (faculty only)
await announcementService.postAnnouncement(
  title: "Final Exam Schedule Released",
  content: "Finals begin June 1st. Check the portal for your timetable.",
  postedBy: currentUser.name,
  postedById: currentUser.id,
  type: "Academic",
);

// Toggle bookmark
await announcementService.bookmarkToggle(userId, announcementId, true);
```

---

### 3.3 Events

- Faculty create campus events with title, description, category, location, date, time, and colour.
- Any authenticated user can RSVP to an event. The `toggle_rsvp` RPC updates both the `users.rsvped_events` array and the `events.attendees` counter atomically.
- Calendar view (via `table_calendar`) for date-based browsing.
- **Offline**: events created offline are queued; an optimistic `IsarEvent` (prefixed `pending_`) is shown immediately. RSVPs are also queued and the local cache updated instantly.

```dart
// Create an event (faculty only)
await eventService.createEvent(
  title: "Spring Tech Conference",
  description: "Annual conference with keynote speakers.",
  category: "Academic",
  location: "Main Auditorium",
  date: DateTime(2026, 5, 15),
  time: "9:00 AM",
  organizer: currentUser.name,
  organizerId: currentUser.id,
);

// RSVP
await eventService.rsvpEvent(eventId, currentUser.id, true);

// Stream all events
eventService.getEvents().listen((events) {
  print("${events.length} upcoming events");
});
```

---

### 3.4 Chat

- One-to-one and group chat rooms.
- Duplicate-room prevention: creating a 1:1 room with an existing member pair returns the existing room.
- Real-time message delivery via Supabase Realtime `INSERT` subscription on `chat_messages`.
- Unread message count tracked per-room using `SharedPreferences` (`last_seen_<roomId>`).
- Presence system via `global_presence` Realtime channel — tracks online users.
- Message length capped at 2 000 characters.
- **Offline**: messages are queued and an optimistic `IsarChatMessage` with prefix `pending_` is inserted locally. On reconnection the optimistic copy is replaced by the real server record.

```dart
// Create a room
final room = await chatService.createRoom(
  name: "Jane & John",
  isGroup: false,
  memberIds: [currentUser.id, otherUser.id],
  memberNames: [currentUser.name, otherUser.name],
  createdById: currentUser.id,
);

// Send a message
await chatService.sendMessage(
  roomId: room.id,
  senderId: currentUser.id,
  senderName: currentUser.name,
  content: "See you at 3 PM!",
);

// Stream messages
chatService.getMessages(room.id).listen((messages) {
  messages.forEach((m) => print("${m.senderName}: ${m.content}"));
});

// Mark room as read
await chatService.markRoomAsRead(room.id);

// Track online users
chatService.onlineUserIds().listen((ids) {
  print("${ids.length} users online");
});
```

---

### 3.5 Resource Sharing

- Any authenticated user can upload PDF, DOCX, PPT/PPTX, JPG, JPEG, or PNG files (max 10 MB).
- Resources tagged with subject, department, semester, and type.
- Download and rating counters updated via Supabase RPC (`increment_downloads`, `rate_resource`).
- Files stored in Supabase Storage bucket `resources` (public).
- **Offline**: the file is copied to a persistent `unisync_pending_uploads/` directory inside the app's documents folder. An optimistic `IsarResource` is inserted. On reconnection the actual binary upload and database insert are performed.

```dart
// Upload a resource
final file = File("/path/to/lecture-notes.pdf");
await resourceService.uploadResource(
  file: file,
  title: "Data Structures — Chapter 5",
  subject: "CS-201",
  department: "Computer Science",
  semester: "3",
  type: "PDF",
  uploadedBy: currentUser.name,
  uploadedById: currentUser.id,
);

// Stream resources
resourceService.getResources(
  department: "Computer Science",
  type: "PDF",
).listen((resources) {
  print("${resources.length} resources found");
});

// Rate a resource
await resourceService.rateResource(resourceId, 4.5);

// Increment download count
await resourceService.incrementDownloads(resourceId);
```

---

### 3.6 Profile Management

- Users update name, department, and semester.
- Avatar photo uploaded to Supabase Storage bucket `avatars`.
- `update_photo_url` RPC handles the UUID–text cast issue from the Dart client.

---

### 3.7 Push Notifications

- OneSignal integration via a Supabase Edge Function (`supabase/functions/send-notification/index.ts`).
- Triggered server-side whenever a new announcement, event, chat message, or resource is posted.
- The Edge Function targets users by their Supabase UID (`OneSignal.login(userId)` sets the External ID).
- The sender is always excluded from their own notification (`excludeUserId`).
- Player IDs persisted in `user_push_tokens` and refreshed on login.

```dart
// Triggered internally by services — not called directly from UI
NotificationService.send(
  type: "announcement",
  title: "📢 New Announcement",
  body: announcementTitle,
  excludeUserId: posterId,
);
```

---

## 4. Project Structure

```
unisync/
├── .env                          # Runtime secrets (never committed)
├── .env.example                  # Template for .env
├── pubspec.yaml                  # Flutter dependencies
├── SUPABASE_SETUP.sql            # Complete DB schema + RLS (run once)
├── NOTIFICATIONS_SETUP.sql       # user_push_tokens table
├── COMPLETE_SETUP_GUIDE.txt      # Step-by-step Firebase/APK build guide
│
├── android/                      # Android-specific config
│   └── app/
│       ├── build.gradle
│       ├── google-services.json  # Firebase config (user-supplied, not committed)
│       └── src/main/
│           ├── AndroidManifest.xml
│           └── kotlin/com/unisync/unisync/MainActivity.kt
│
├── assets/
│   └── images/
│       ├── app_icon.png
│       ├── background.jpg
│       ├── logo.png
│       └── logo_bg.png
│
├── supabase/
│   └── functions/
│       └── send-notification/
│           └── index.ts          # Deno Edge Function for push notifications
│
├── lib/
│   ├── main.dart                 # App entry point, initialisation, AuthGate
│   │
│   ├── theme/
│   │   └── app_theme.dart        # Global MaterialApp theme
│   │
│   ├── models/                   # Plain Dart models + Isar persistent models
│   │   ├── user_model.dart
│   │   ├── announcement_model.dart
│   │   ├── event_model.dart
│   │   ├── chat_model.dart
│   │   ├── resource_model.dart
│   │   ├── isar_announcement.dart / .g.dart
│   │   ├── isar_event.dart / .g.dart
│   │   ├── isar_chat.dart / .g.dart
│   │   ├── isar_resource.dart / .g.dart
│   │   └── isar_pending_action.dart / .g.dart
│   │
│   ├── providers/                # Riverpod providers
│   │   ├── auth_provider.dart
│   │   ├── announcement_provider.dart
│   │   ├── chat_provider.dart
│   │   ├── connectivity_provider.dart
│   │   ├── event_provider.dart
│   │   ├── marking_provider.dart
│   │   └── resource_provider.dart
│   │
│   ├── services/                 # Business logic / data access layer
│   │   ├── supabase_client.dart        # Singleton supabase accessor
│   │   ├── auth_service.dart
│   │   ├── announcement_service.dart
│   │   ├── chat_service.dart
│   │   ├── event_service.dart
│   │   ├── resource_service.dart
│   │   ├── profile_service.dart
│   │   ├── marking_service.dart
│   │   ├── notification_service.dart
│   │   ├── connectivity_service.dart
│   │   ├── local_database_service.dart # Isar CRUD + queue management
│   │   └── offline_sync_service.dart   # Pending-action replay engine
│   │
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   └── signup_screen.dart
│   │   ├── onboarding/
│   │   │   └── onboarding_screen.dart
│   │   ├── dashboard/
│   │   │   ├── main_dashboard.dart     # Bottom-nav shell
│   │   │   ├── home_tab.dart
│   │   │   └── announcements_screen.dart
│   │   ├── chat/
│   │   │   ├── chat_list_screen.dart
│   │   │   ├── chat_room_screen.dart
│   │   │   └── new_chat_screen.dart
│   │   ├── events/
│   │   │   ├── events_list_screen.dart
│   │   │   ├── event_creation_screen.dart
│   │   │   └── event_detail_screen.dart
│   │   ├── resources/
│   │   │   ├── resources_screen.dart
│   │   │   ├── resource_detail_screen.dart
│   │   │   └── resource_upload_screen.dart
│   │   └── profile/
│   │       ├── profile_screen.dart
│   │       └── edit_profile_screen.dart
│   │
│   └── widgets/
│       └── shared_widgets.dart   # Reusable UI components
│
└── test/
    └── widget_test.dart
```

---

## 5. Architecture & Data Flow

### Initialisation Sequence (`main.dart`)

```
1. Load .env (flutter_dotenv)
2. Firebase.initializeApp()          ← required before OneSignal
3. LocalDatabaseService.initialize() ← open Isar DB
4. ConnectivityService.initialize()  ← start network monitoring
5. Supabase.initialize()             ← connect to Supabase
6. NotificationService.initialize()  ← init OneSignal, upload player ID
7. runApp(ProviderScope(UniSyncApp))
```

### AuthGate Logic

```
Session exists?
  └─ YES → load user profile → join presence → upload push token → MainDashboard
  └─ NO  → onboarding_done flag?
              └─ YES → LoginScreen
              └─ NO  → OnboardingScreen
```

### Service Layer Pattern (Cache-First)

Every service follows the same pattern:

```
getXxx() → Stream
  1. Emit Isar cache instantly (works offline)
  2. If offline → return (stream stays on cached data)
  3. Fetch from Supabase via HTTP
  4. Write fresh data to Isar
  5. Emit updated data to UI
  6. Subscribe to Supabase Realtime → on change, re-fetch and re-emit
```

---

## 6. Data Models

### `AppUser`

| Field | Type | Notes |
|---|---|---|
| `id` | `String` (UUID) | Matches `auth.users.id` |
| `name` | `String` | |
| `email` | `String` | University domain enforced |
| `department` | `String` | |
| `semester` | `String` | |
| `studentId` | `String` | 8 digits; prefix determines role |
| `role` | `String` | `'student'` or `'faculty'` |
| `photoUrl` | `String?` | Public URL in `avatars` bucket |
| `bookmarkedAnnouncements` | `List<String>` | Array of announcement UUIDs |
| `rsvpedEvents` | `List<String>` | Array of event UUIDs |

### `Announcement`

| Field | Type | Notes |
|---|---|---|
| `id` | `String` (UUID) | |
| `title` | `String` | |
| `content` | `String` | |
| `postedBy` | `String` | Display name |
| `postedById` | `String` (UUID) | |
| `postedAt` | `DateTime` | |
| `type` | `String` | `Academic` / `Financial` / `General` / `Club` |
| `isBookmarked` | `bool` | Local state only |

### `Event`

| Field | Type | Notes |
|---|---|---|
| `id` | `String` (UUID) | |
| `title` | `String` | |
| `description` | `String` | |
| `category` | `String` | |
| `location` | `String` | |
| `date` | `DateTime` | |
| `time` | `String` | Human-readable time string |
| `attendees` | `int` | Managed by `toggle_rsvp` RPC |
| `organizer` | `String` | Display name |
| `organizerId` | `String` (UUID) | |
| `imageColor` | `String` | Hex without `#` (e.g. `"1A56DB"`) |
| `isRSVPed` | `bool` | Local state |

### `ChatRoom`

| Field | Type | Notes |
|---|---|---|
| `id` | `String` (UUID) | |
| `name` | `String` | |
| `lastMessage` | `String` | Truncated preview (max 60 chars) |
| `lastMessageTime` | `DateTime` | |
| `isGroup` | `bool` | |
| `memberIds` | `List<String>` | Array of UUIDs |
| `memberNames` | `List<String>` | |
| `memberPhotoUrls` | `List<String?>` | Enriched client-side |
| `avatarColor` | `String` | Hex without `#` |
| `unreadCount` | `int` | Computed client-side |

### `ChatMessage`

| Field | Type | Notes |
|---|---|---|
| `id` | `String` (UUID) | Prefix `pending_` for optimistic messages |
| `roomId` | `String` (UUID) | |
| `senderId` | `String` (UUID) | |
| `senderName` | `String` | |
| `content` | `String` | Max 2 000 characters |
| `createdAt` | `DateTime` | |

### `Resource`

| Field | Type | Notes |
|---|---|---|
| `id` | `String` (UUID) | |
| `title` | `String` | |
| `subject` | `String` | |
| `department` | `String` | |
| `semester` | `String` | |
| `type` | `String` | `PDF`, `DOCX`, `PPT`, `JPG`, `JPEG`, `PNG` |
| `fileUrl` | `String` | Public Supabase Storage URL |
| `storagePath` | `String` | Storage path used for deletion |
| `size` | `String` | Formatted, e.g. `"512 KB"` |
| `downloads` | `int` | Incremented via RPC |
| `rating` | `double` | Rolling average (0–5) |
| `ratingCount` | `int` | |
| `uploadedBy` | `String` | Display name |
| `uploadedById` | `String` (UUID) | |
| `uploadedAt` | `DateTime` | |
| `iconColor` | `String` | Hex without `#` |

---

## 7. API & Service Documentation

### `AuthService`

| Method | Returns | Description |
|---|---|---|
| `signUp(name, email, password, department, semester, studentId)` | `Future<AppUser>` | Creates Supabase Auth user + inserts `users` row. Validates name non-empty, password ≥ 8 chars. |
| `signIn(email, password)` | `Future<AppUser>` | Signs in and validates university email domain. |
| `signOut()` | `Future<void>` | Clears local cache and signs out from Supabase. |
| `sendPasswordReset(email)` | `Future<void>` | Sends Supabase password reset email. |
| `getUser(uid)` | `Future<AppUser>` | Fetches from Supabase; falls back to `SharedPreferences` cache when offline. |
| `updateUser(uid, {name, department, semester})` | `Future<void>` | Updates profile fields. Refreshes cache on success. |

**Friendly error helper**: `friendlyAuthError(Object e)` maps raw Supabase/network exceptions to human-readable strings shown in the UI.

---

### `AnnouncementService`

| Method | Returns | Description |
|---|---|---|
| `getAnnouncements({type})` | `Stream<List<Announcement>>` | Cache-first stream with Realtime subscription. Accepts optional `type` filter (`null` = all). |
| `postAnnouncement({title, content, postedBy, postedById, type})` | `Future<void>` | **Online**: inserts to Supabase + triggers push. **Offline**: queues `post_announcement` + optimistic insert. |
| `bookmarkToggle(userId, announcementId, add)` | `Future<void>` | Calls `append_bookmark` / `remove_bookmark` RPCs. Falls back to local update when offline. |
| `deleteAnnouncement(id)` | `Future<void>` | Soft-deletes locally (`isDeleted = true`). **Online**: deletes from Supabase. **Offline**: queues `delete_announcement`. |
| `syncDeletions()` | `Future<void>` | Replays queued deletions on reconnect. |

---

### `ChatService`

| Method | Returns | Description |
|---|---|---|
| `getRooms(userId)` | `Stream<List<ChatRoom>>` | Cache-first stream with Realtime updates. Filtered by `memberIds`. |
| `getRoomsWithUnread(userId)` | `Stream<List<ChatRoom>>` | Wraps `getRooms` + enriches with photo URLs and unread counts. |
| `getMessages(roomId)` | `Stream<List<ChatMessage>>` | Cache-first + Realtime `INSERT` subscription. |
| `createRoom({name, isGroup, memberIds, memberNames, createdById})` | `Future<ChatRoom>` | Prevents duplicate 1:1 rooms. Requires online connection. |
| `sendMessage({roomId, senderId, senderName, content})` | `Future<void>` | **Online**: inserts to Supabase + push notification. **Offline**: queues `send_message` + optimistic `pending_*` message. |
| `deleteMessage(messageId)` | `Future<void>` | Deletes locally. **Online**: deletes from Supabase. **Offline**: queues `delete_message` (skips `pending_*` IDs). |
| `markRoomAsRead(roomId)` | `Future<void>` | Saves timestamp to `SharedPreferences`. |
| `getUnreadCount(roomId)` | `Future<int>` | Computes unread count vs. `last_seen_<roomId>`. Works online and offline. |
| `joinPresence(userId, userName)` | `void` | Subscribes to `global_presence` Realtime channel. No-op when offline. |
| `leavePresence()` | `void` | Untracks user from presence channel. |
| `onlineUserIds()` | `Stream<Set<String>>` | Emits the current set of online user IDs. |

---

### `EventService`

| Method | Returns | Description |
|---|---|---|
| `getEvents()` | `Stream<List<Event>>` | Cache-first stream with Realtime subscription. |
| `createEvent({title, description, category, location, date, time, organizer, organizerId})` | `Future<void>` | **Online**: inserts to Supabase + push. **Offline**: queues `create_event` + optimistic local insert. |
| `rsvpEvent(eventId, userId, going)` | `Future<void>` | **Online**: calls `toggle_rsvp` RPC. **Offline**: updates local cache + queues `rsvp_event`. |
| `deleteEvent(id)` | `Future<void>` | Deletes locally + Supabase (or queues `delete_event`). |

---

### `ResourceService`

| Method | Returns | Description |
|---|---|---|
| `getResources({department, type})` | `Stream<List<Resource>>` | Cache-first stream with optional filters and Realtime subscription. |
| `uploadResource({file, title, subject, department, semester, type, uploadedBy, uploadedById})` | `Future<void>` | Validates size (≤ 10 MB) and extension. **Online**: uploads to Storage + inserts row. **Offline**: copies file locally, queues `upload_resource`, inserts optimistic record. |
| `incrementDownloads(id)` | `Future<void>` | Calls `increment_downloads` RPC. No-op when offline. |
| `rateResource(id, rating)` | `Future<void>` | Calls `rate_resource` RPC. No-op when offline. |
| `deleteResource(id, storagePath)` | `Future<void>` | Removes from Storage + deletes row. **Offline**: queues `delete_resource`. |

**Allowed file extensions**: `pdf`, `doc`, `docx`, `ppt`, `pptx`, `jpg`, `jpeg`, `png`
**Maximum file size**: 10 MB

---

### `OfflineSyncService`

| Method | Returns | Description |
|---|---|---|
| `syncAll()` | `Future<int>` | Iterates all unsent `IsarPendingAction` records in insertion order and replays them. Returns count of successfully synced actions. No-op when offline. |
| `pendingCount()` | `Future<int>` | Returns number of queued pending actions. |

**Supported action types replayed by `syncAll`**:

| `actionType` | Supabase operation |
|---|---|
| `send_message` | Insert to `chat_messages`, update `chat_rooms.last_message` |
| `post_announcement` | Insert to `announcements` |
| `create_event` | Insert to `events` |
| `upload_resource` | Upload binary to Storage + insert to `resources` |
| `rsvp_event` | Call `toggle_rsvp` RPC |
| `delete_message` | Delete from `chat_messages` |
| `delete_announcement` | Delete from `announcements` |
| `delete_event` | Delete from `events` |
| `delete_resource` | Remove from Storage + delete from `resources` |

Actions exceeding **5 retries** are abandoned and marked synced to unblock the queue.

---

### `NotificationService`

| Method | Returns | Description |
|---|---|---|
| `initialize(oneSignalAppId)` | `Future<void>` | Inits OneSignal SDK, requests permission, uploads player ID, registers observers. |
| `uploadPendingToken()` | `Future<void>` | Calls `OneSignal.login(userId)` and upserts player ID to `user_push_tokens`. |
| `send(type, title, body, excludeUserId)` *(static)* | `Future<void>` | Invokes Supabase Edge Function `send-notification`. |

---

### `ConnectivityService`

Singleton. Uses `connectivity_plus` to monitor network state.

| Property / Method | Type | Description |
|---|---|---|
| `isOnline` | `bool` | Current connectivity state |
| `isOffline` | `bool` | Inverse of `isOnline` |
| `onConnectionRestored` | `void Function()?` | Callback fired when connectivity transitions from offline → online |
| `initialize()` | `Future<void>` | Starts listening to connectivity changes |

---

### `LocalDatabaseService`

Isar-backed singleton. Opens the database with schemas for all five entity types plus the pending-action queue.

| Entity | Key methods |
|---|---|
| Announcements | `cacheAnnouncements`, `getCachedAnnouncements`, `deleteAnnouncement`, `updateAnnouncementBookmark` |
| Events | `cacheEvents`, `getCachedEvents`, `deleteEvent`, `updateEventRsvp` |
| Chat Rooms | `cacheChatRooms`, `getCachedChatRooms` |
| Chat Messages | `cacheMessages`, `getCachedMessages`, `deleteMessage`, `removeSyncedOptimisticMessages` |
| Resources | `cacheResources`, `getCachedResources`, `deleteResource` |
| Pending Actions | `enqueuePendingAction`, `getPendingActions`, `markActionSynced`, `incrementActionRetry`, `clearSyncedActions`, `pendingActionCount` |

---

## 8. Database Schema

### Tables

**`users`**
```sql
id                       uuid  PK (references auth.users)
name                     text  NOT NULL
email                    text  NOT NULL
department               text  DEFAULT 'Computer Science'
semester                 text
student_id               text               -- determines role
role                     text  CHECK ('student'|'faculty')
photo_url                text  NULLABLE
bookmarked_announcements uuid[]
rsvped_events            uuid[]
created_at               timestamptz
```

**`events`**
```sql
id           uuid  PK
title        text  NOT NULL
description  text
category     text
location     text
date         timestamptz  NOT NULL
time         text
attendees    int   DEFAULT 0
organizer    text
organizer_id uuid  REFERENCES users
image_color  text
created_at   timestamptz
```

**`resources`**
```sql
id              uuid  PK
title           text
subject         text
department      text
semester        text
type            text  (PDF/DOCX/PPT/JPG/JPEG/PNG)
file_url        text
storage_path    text
size            text
downloads       int   DEFAULT 0
rating          float DEFAULT 0
rating_count    int   DEFAULT 0
uploaded_by     text
uploaded_by_id  uuid  REFERENCES users
uploaded_at     timestamptz
icon_color      text
```

**`announcements`**
```sql
id           uuid  PK
title        text
content      text
posted_by    text
posted_by_id uuid  REFERENCES users
posted_at    timestamptz
type         text  CHECK ('Academic'|'Financial'|'General'|'Club')
```

**`chat_rooms`**
```sql
id                uuid  PK
name              text
last_message      text
last_message_time timestamptz
is_group          boolean
member_ids        uuid[]
member_names      text[]
avatar_color      text
```

**`chat_messages`**
```sql
id          uuid  PK
room_id     uuid  REFERENCES chat_rooms ON DELETE CASCADE
sender_id   uuid  REFERENCES users
sender_name text
content     text  (max 2000 chars)
created_at  timestamptz
```

### RPC Functions

| Function | Purpose |
|---|---|
| `assign_role_from_id()` | Trigger: sets `role` from `student_id` format on user insert |
| `append_bookmark(user_id, ann_id)` | Atomically appends to `bookmarked_announcements` |
| `remove_bookmark(user_id, ann_id)` | Atomically removes from `bookmarked_announcements` |
| `toggle_rsvp(p_event_id, p_user_id, p_going)` | Atomically updates RSVP and attendee count |
| `increment_downloads(resource_id)` | Increments `downloads` counter |
| `rate_resource(p_resource_id, p_rating)` | Computes rolling average rating |
| `update_photo_url(p_user_id, p_photo_url)` | Updates avatar URL (handles UUID–text cast) |

### Indexes

```sql
idx_events_date        ON events(date)
idx_announcements_date ON announcements(posted_at DESC)
idx_messages_room      ON chat_messages(room_id, created_at)
idx_resources_dept     ON resources(department)
```

---

## 9. Offline-First Architecture

### Pending Action Queue

`IsarPendingAction` stores write operations that could not reach Supabase while the device was offline.

| Field | Type | Description |
|---|---|---|
| `id` | `int` | Isar auto-increment |
| `actionType` | `String` | Identifies the operation to replay |
| `payloadJson` | `String` | JSON-serialised parameters |
| `localTempId` | `String?` | Links the action to an optimistic local record |
| `createdAt` | `DateTime` | Determines replay order (FIFO) |
| `retryCount` | `int` | Incremented on failure; abandoned after 5 |
| `isSynced` | `bool` | Cleared by `clearSyncedActions` |

### Optimistic IDs

Any locally-created record not yet persisted to Supabase is given a `remoteId` with the prefix `pending_`. The UI renders these records identically to server records. On the next successful sync the optimistic copy is deleted and replaced by the real server row.

### Connection Restoration

`ConnectivityService.onConnectionRestored` is wired in `main.dart` to trigger `OfflineSyncService.syncAll()`. Individual services also expose `syncDeletions()` for their respective entities.

---

## 10. Push Notification System

### Flow

```
Client action (announcement / event / message / resource)
  └─ Service calls NotificationService.send(type, title, body, excludeUserId)
       └─ Invokes Supabase Edge Function 'send-notification'
            └─ Edge Function queries 'user_push_tokens' for all users except sender
                 └─ Calls OneSignal API /notifications with include_aliases.external_id
```

### Edge Function Environment Variables

Set in the Supabase dashboard under **Project Settings → Edge Functions**:

| Variable | Description |
|---|---|
| `ONESIGNAL_APP_ID` | OneSignal application ID |
| `ONESIGNAL_REST_API_KEY` | OneSignal REST API key |
| `SUPABASE_URL` | Project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key (bypasses RLS to read all push tokens) |

### Notification Types

| `type` | Trigger |
|---|---|
| `announcement` | New announcement posted |
| `event` | New event created |
| `chat` | New chat message sent |
| `resource` | New resource uploaded |

---

## 11. Authentication & Role System

### Role Assignment (Database Trigger)

The trigger `trg_assign_role_from_id` fires `BEFORE INSERT` on `users`:

- `student_id` matching `^3[0-9]{7}$` → `role = 'student'`
- `student_id` matching `^1[0-9]{7}$` → `role = 'faculty'`
- Any other format → `RAISE EXCEPTION`

This ensures roles are always server-authoritative and cannot be spoofed by the client.

### Permission Matrix

| Action | Student | Faculty |
|---|---|---|
| Read announcements | ✅ | ✅ |
| Post announcement | ❌ | ✅ |
| Delete own announcement | ❌ | ✅ |
| Read events | ✅ | ✅ |
| Create event | ❌ | ✅ |
| Delete own event | ✅ | ✅ |
| RSVP to event | ✅ | ✅ |
| Upload resource | ✅ | ✅ |
| Delete own resource | ✅ | ✅ |
| Delete any resource | ❌ | ✅ |
| Send / receive chat | ✅ | ✅ |

---

## 12. Environment Configuration

Copy `.env.example` to `.env` and populate all values before running or building.

```env
SUPABASE_URL=https://<project-id>.supabase.co
SUPABASE_ANON_KEY=eyJhbGci...
ONESIGNAL_APP_ID=<onesignal-app-id>
```

The `.env` file is bundled as a Flutter asset (declared in `pubspec.yaml`) and loaded at startup via `flutter_dotenv`. It is listed in `.gitignore` and must **never** be committed to version control.

---

## 13. Build & Deployment

### Prerequisites

- Flutter SDK ≥ 3.2.0
- Android SDK / Android Studio
- Firebase project with Android app configured
- Supabase project with schema applied (`SUPABASE_SETUP.sql`)
- OneSignal account and app

### First-Time Setup

1. Run `SUPABASE_SETUP.sql` in the Supabase SQL Editor.
2. Run `NOTIFICATIONS_SETUP.sql` in the Supabase SQL Editor.
3. Create Storage buckets `resources` and `avatars` (both public) in the Supabase dashboard.
4. Deploy the Edge Function: `supabase functions deploy send-notification`
5. Set Edge Function environment variables in the Supabase dashboard.
6. Download `google-services.json` from the Firebase console and place it at `android/app/google-services.json`.
7. Populate `.env` with Supabase and OneSignal credentials.

### Build Commands

```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --release
```

Release APK: `build/app/outputs/apk/release/app-release.apk`

---

## 14. Row-Level Security Policies

All six tables have RLS enabled. Summary:

| Table | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| `users` | Any authenticated user | Own row only | Own row only | — |
| `events` | Any authenticated | Faculty only | Any authenticated | Faculty or organizer |
| `resources` | Any authenticated | Any authenticated | Any authenticated | Uploader or faculty |
| `announcements` | Any authenticated | Faculty only | — | Poster or faculty |
| `chat_rooms` | Members only | Any authenticated | Members only | — |
| `chat_messages` | Room members only | Sender is member | — | — |

The Edge Function uses `SUPABASE_SERVICE_ROLE_KEY` to bypass RLS when reading all user push tokens.

---

## 15. Troubleshooting

### `google-services.json` not found
```bash
ls android/app/google-services.json
# If missing: Firebase Console → Project Settings → Your Apps → Android → Download
```

### Isar model errors after pulling new code
```bash
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
flutter clean && flutter pub get
```

### OneSignal initialisation failed

Ensure Firebase is initialised **before** OneSignal in `main.dart`:
```dart
await Firebase.initializeApp();
await NotificationService.instance.initialize(appId);
```

### App cannot connect to backend

Verify `SUPABASE_URL` and `SUPABASE_ANON_KEY` in `.env` match the values in Supabase → Project Settings → API:
```bash
grep SUPABASE .env
```

### Infinite loading / shimmer on chat rooms

This is caused by Supabase's `.stream()` method failing on carrier NAT or restrictive firewalls. `ChatService.getRooms()` uses `.select()` + Realtime instead, which resolves it. Ensure you are on the latest version of the code.

### Device not detected
```bash
flutter devices
# Enable USB Debugging on your Android phone under Developer Options
```
