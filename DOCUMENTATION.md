# UniSync — Technical Documentation

UniSync is a Flutter mobile application for universities. It gives students and faculty a single platform for announcements, events, course resources, and messaging built offline-first so it works fully without internet and syncs automatically when connectivity returns.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Core Functionalities](#2-core-functionalities)
3. [Project Structure](#3-project-structure)
4. [API Documentation](#4-api-documentation)
   - [AuthService](#41-authservice)
   - [AnnouncementService](#42-announcementservice)
   - [EventService](#43-eventservice)
   - [ResourceService](#44-resourceservice)
   - [ChatService](#45-chatservice)
   - [ProfileService](#46-profileservice)
   - [NotificationService](#47-notificationservice)
   - [ConnectivityService](#48-connectivityservice)
   - [OfflineSyncService](#49-offlinesynccservice)
   - [LocalDatabaseService](#410-localdatabaseservice)
   - [MarkingService](#411-markingservice)
   - [Edge Function — send-notification](#412-edge-function--send-notification)
5. [Database Schema](#5-database-schema)
6. [Tech Stack](#6-tech-stack)

---

## 1. Project Overview

UniSync replaces the scattered mix of email chains, WhatsApp groups, and notice boards that most universities rely on. Everything lives in one app:

- **Faculty** post announcements and create events. Students are notified instantly via push.
- **Students** RSVP to events, see live attendee counts, and bookmark announcements to read later.
- **Everyone** uploads and downloads study materials- notes, past papers, slides- organized by department and semester.
- **Direct and group chat** with real-time presence indicators shows who is online.
- **Offline mode** is a first-class feature, not an afterthought. The app reads from a local Isar NoSQL database instantly, queues any writes that happen without internet, and replays them automatically when connectivity is restored.

### Who can do what

Roles are assigned automatically by the database at sign-up based on the student ID format. There is no role selection screen, the ID number determines access.

| Role | Assigned when | Permissions |
|---|---|---|
| `student` | Student ID matches `3XXXXXXX` | Read all content · upload resources · chat · RSVP |
| `faculty` | Student ID matches `1XXXXXXX` | All student rights · post announcements · create events · delete any content in their domain |

The role is set by a PostgreSQL `BEFORE INSERT` trigger (`trg_assign_role_from_id`) and is immutable from the client. RLS policies enforce it on every query.

### App flow

```
First launch
  └─ OnboardingScreen (3 slides + role/ID selection)
       └─ SignupScreen (pre-filled with role and ID from onboarding)
            └─ MainDashboard

Returning user
  └─ LoginScreen
       └─ MainDashboard (5 tabs: Home · Events · Resources · Chat · Profile)

Sign out → LoginScreen  (onboarding is never shown again)
```

---

## 2. Core Functionalities

### 2.1 Authentication

Sign-up, sign-in, sign-out, and password reset via Supabase Auth. Only university email domains are accepted: `.edu`, `.edu.bd`, `.ac.bd`, `.ac.uk`, `.ac.in`.

After every successful auth call the full user profile is serialized to `SharedPreferences` under the key `cached_user_profile`. If a subsequent `getUser()` call fails due to no network, the cached copy is returned instead, so profile data is always available offline.

Sign-out clears this cache. The `onboarding_done` flag is persisted separately, so returning users always land on the login screen rather than onboarding.

### 2.2 Announcements

Faculty post announcements of four types: **Academic**, **Financial**, **General**, **Club**. All authenticated users can read them, filter by type, and bookmark individual ones.

Bookmarks are stored atomically in `users.bookmarked_announcements UUID[]` via `append_bookmark` and `remove_bookmark` RPC functions, these use `array_remove` before `array_append` to deduplicate, preventing race conditions. The local Isar cache preserves `isBookmarked` across server refreshes so the flag is never lost on a cache update.

Every stream emits from Isar first (instant, works offline), then re-emits from Supabase, then subscribes to a Realtime channel named `announcements_<type|all>` for live updates.

Offline posting: the announcement is inserted into Isar with a `pending_` prefix ID and appears in the UI immediately. An `IsarPendingAction` is queued; `OfflineSyncService` inserts it to Supabase and fires the push notification when connectivity returns.

### 2.3 Events

Faculty create events with title, description, category, location, date, time. A colour is auto-assigned from a palette (deterministic on `DateTime.now().millisecond`) for the card illustration.

Students RSVP with a single toggle. The `toggle_rsvp` PostgreSQL RPC atomically:
1. Adds or removes the event UUID from `users.rsvped_events[]`
2. Increments or decrements `events.attendees` (floored at `0`)

`isRSVPed` on each emitted `Event` object is resolved client-side by checking `user.rsvpedEvents`, no extra join needed. Live attendee counts update via the `events_changes` Realtime channel.

Offline: both `createEvent` and `rsvpEvent` update Isar immediately and queue `IsarPendingAction` records for server replay.

### 2.4 Course Resources

Any authenticated user can upload study materials. Files go to Supabase Storage bucket `resources` (public). Metadata is stored in the `resources` table.

**Allowed extensions:** `pdf`, `doc`, `docx`, `ppt`, `pptx`, `jpg`, `jpeg`, `png`  
**Max file size:** 10 MB (enforced in `ResourceService` before the upload attempt)

Each resource tracks:
- **Downloads**-incremented atomically via `increment_downloads(resource_id)` RPC on every download
- **Rating**-running average computed by `rate_resource(resource_id, rating)` RPC: `new_avg = ((old_rating × old_count) + new_rating) / (old_count + 1)`

Offline upload: the raw file bytes are written to `<appDocuments>/unisync_pending_uploads/pending_<timestamp>.<ext>` — a path that survives app restarts. An optimistic `IsarResource` shows the upload immediately. `OfflineSyncService` reads the saved file and uploads it when back online.

### 2.5 Chat & Messaging

Supports direct (1-to-1) and group rooms. Rooms use `select()` + Realtime subscription rather than `.stream()` to avoid infinite loading issues caused by unstable WebSocket connections on mobile carrier NAT and firewalls.

**Presence** is tracked via a Supabase Presence channel named `global_presence`. Each user tracks `{user_id, name}`. `onlineStream` is a `Stream<Set<String>>` that broadcasts the current set of online user IDs to widgets.

**Unread count** per room: a `last_seen_<roomId>` timestamp is stored in `SharedPreferences` via `markRoomAsRead()`. Unread is computed as the number of messages after that timestamp not sent by the current user from Supabase when online, from Isar when offline.

**Sending a message — online:**
1. Validate sender is in `chat_rooms.member_ids`
2. Insert into `chat_messages`
3. Update `chat_rooms.last_message` and `last_message_time`
4. Call `NotificationService.send()` (excluding the sender)

**Sending a message — offline:**
1. Generate temp ID `pending_<timestamp>_<senderId>`
2. Insert optimistic `IsarChatMessage` so the message appears immediately
3. Queue `IsarPendingAction(actionType: 'send_message')`

On reconnection, `OfflineSyncService` replays the send. After the Supabase fetch, `removeSyncedOptimisticMessages()` cleans up `pending_` entries whose content now exists in the server results.

For DMs, `createRoom()` checks for an existing room between the two users before inserting — so you never get duplicate rooms.

### 2.6 Push Notifications

Two-layer stack:

- **Firebase Cloud Messaging (FCM)**-delivery infrastructure. Must be initialized before OneSignal.
- **OneSignal**-targeting, token management, analytics. Users are identified by their Supabase UID via `OneSignal.login(uid)`, which sets the OneSignal external ID. This is more reliable than subscription ID, which can rotate.

Device tokens are stored in `user_push_tokens` (added by `NOTIFICATIONS_SETUP.sql`). If the user isn't authenticated at init time, the token is held in `SharedPreferences` under `pending_onesignal_id` and uploaded after the next login via `uploadPendingToken()`.

Notifications are dispatched by calling the `send-notification` Supabase Edge Function (Deno/TypeScript) after every significant write. The function queries all user IDs, excludes the sender, and POSTs to the OneSignal REST API.

### 2.7 Offline-First Architecture

Every data stream follows the same three-tier pattern:

```
Tier 1  Isar cache         Emits immediately on subscription. Always available. < 50 ms.
Tier 2  Supabase REST      If online: SELECT, update Isar cache, re-emit. 10 s timeout.
Tier 3  Supabase Realtime  If online: subscribe to postgres_changes. On event: re-fetch, re-emit.
```

Offline writes are captured as `IsarPendingAction` records. Each record stores `actionType`, a JSON `payloadJson` with everything needed to replay it, a `localTempId` for the optimistic UI item, and a `retryCount`.

`ConnectivityService` listens to `connectivity_plus` and fires `onConnectionRestored` when transitioning from offline → online. `main.dart` wires this callback to `OfflineSyncService.syncAll()`.

`syncAll()` iterates pending actions in creation order. On success: `markActionSynced()`. On failure: `incrementActionRetry()`. After 5 failures: the action is abandoned (marked synced to unblock the queue). After each run: `clearSyncedActions()` prunes completed records.

Local-only Isar fields (`isBookmarked`, `isRSVPed`, `isDeleted`) are never overwritten by server refreshes — the upsert logic reads the existing record by `remoteId` and copies these fields across before calling `put()`.

### 2.8 User Profiles

Users can update their display name and semester. Profile pictures upload to the `avatars` bucket (public) with `upsert: true`, then `update_photo_url(p_user_id TEXT, p_photo_url TEXT)` RPC is called instead of a direct update. This RPC exists to work around a `operator does not exist: uuid = text` error that the Dart Supabase client throws when filtering by UUID from a text parameter.

User search (`searchUsers`) does a case-insensitive `ILIKE` on `users.name`. Minimum 2 characters (prevents bulk enumeration). Capped at 20 results. Returns only: `id`, `name`, `email`, `department`, `semester`, `photo_url`, `role` — never `student_id`.

---

## 3. Project Structure

```
unisync/
├── lib/
│   ├── main.dart                          # App entry point
│   │                                      # Init order: dotenv → Firebase → Isar
│   │                                      # → ConnectivityService → Supabase
│   │                                      # → OneSignal → ProviderScope
│   │
│   ├── models/
│   │   ├── user_model.dart                # AppUser
│   │   ├── announcement_model.dart        # Announcement
│   │   ├── chat_model.dart                # ChatRoom, ChatMessage
│   │   ├── event_model.dart               # Event
│   │   ├── resource_model.dart            # Resource
│   │   ├── isar_announcement.dart         # Isar collection schema
│   │   ├── isar_chat.dart                 # Isar collection schema (room + message)
│   │   ├── isar_event.dart                # Isar collection schema
│   │   ├── isar_resource.dart             # Isar collection schema
│   │   ├── isar_pending_action.dart       # Offline write queue schema
│   │   └── *.g.dart                       # Generated — do not edit manually
│   │
│   ├── services/
│   │   ├── auth_service.dart              # signUp · signIn · signOut · getUser
│   │   ├── announcement_service.dart      # getAnnouncements · postAnnouncement
│   │   │                                  # bookmarkToggle · deleteAnnouncement
│   │   ├── chat_service.dart              # getRooms · getMessages · sendMessage
│   │   │                                  # createRoom · presence · unread
│   │   ├── event_service.dart             # getEvents · createEvent · rsvpEvent
│   │   │                                  # deleteEvent
│   │   ├── resource_service.dart          # getResources · uploadResource
│   │   │                                  # incrementDownloads · rateResource
│   │   │                                  # deleteResource
│   │   ├── profile_service.dart           # uploadProfilePhoto · searchUsers
│   │   ├── notification_service.dart      # initialize · uploadPendingToken
│   │   │                                  # send() [static]
│   │   ├── connectivity_service.dart      # isOnline · isOffline
│   │   │                                  # onConnectionRestored callback
│   │   ├── offline_sync_service.dart      # syncAll · pendingCount
│   │   ├── marking_service.dart           # toggleResourceBookmark
│   │   │                                  # syncBookmarks
│   │   ├── local_database_service.dart    # Isar open/close + all cache ops
│   │   └── supabase_client.dart           # Supabase singleton (supabase getter)
│   │
│   ├── providers/
│   │   ├── auth_provider.dart             # authStateProvider
│   │   │                                  # currentUserProvider (StateNotifier)
│   │   │                                  # authServiceProvider
│   │   ├── announcement_provider.dart     # announcementServiceProvider
│   │   ├── chat_provider.dart             # chatServiceProvider
│   │   ├── event_provider.dart            # eventServiceProvider
│   │   ├── resource_provider.dart         # resourceServiceProvider
│   │   ├── connectivity_provider.dart     # connectivityServiceProvider
│   │   └── marking_provider.dart          # markingServiceProvider
│   │
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── login_screen.dart          # Email + password · forgot password
│   │   │   └── signup_screen.dart         # Pre-filled role + ID from onboarding
│   │   ├── onboarding/
│   │   │   └── onboarding_screen.dart     # 3 feature slides → role/ID selection
│   │   │                                  # Validates ID regex before proceeding
│   │   ├── dashboard/
│   │   │   ├── main_dashboard.dart        # IndexedStack · 5-tab bottom nav
│   │   │   │                              # BackdropFilter frosted glass nav bar
│   │   │   ├── home_tab.dart              # Announcement feed (home tab)
│   │   │   └── announcements_screen.dart  # Full list + type filter chips
│   │   ├── chat/
│   │   │   ├── chat_list_screen.dart      # Room list with unread badges
│   │   │   ├── chat_room_screen.dart      # Message thread + send bar
│   │   │   └── new_chat_screen.dart       # searchUsers → create DM or group
│   │   ├── events/
│   │   │   ├── events_list_screen.dart
│   │   │   ├── event_detail_screen.dart   # RSVP toggle + live attendee count
│   │   │   └── event_creation_screen.dart # Faculty only
│   │   ├── resources/
│   │   │   ├── resources_screen.dart      # Filter by department + type
│   │   │   ├── resource_detail_screen.dart # Download + star rating
│   │   │   └── resource_upload_screen.dart
│   │   └── profile/
│   │       ├── profile_screen.dart
│   │       └── edit_profile_screen.dart   # Name · semester · avatar upload
│   │
│   ├── widgets/
│   │   └── shared_widgets.dart            # Cards · shimmer loaders · empty states
│   │
│   └── theme/
│       └── app_theme.dart                 # AppTheme.primary · AppTheme.ink900 etc.
│                                          # Material 3 theme + AppBackground widget
│
├── supabase/
│   └── functions/
│       └── send-notification/
│           └── index.ts                   # Deno edge function — OneSignal dispatch
│
├── android/
│   └── app/
│       ├── google-services.json           # Firebase — never commit real values
│       └── src/main/kotlin/.../MainActivity.kt
│
├── assets/
│   └── images/
│       ├── logo.png
│       ├── logo_bg.png
│       └── background.jpg
│
├── sql/
│   ├── SUPABASE_SETUP.sql                 # Full DB bootstrap-run once in SQL Editor
│   └── NOTIFICATIONS_SETUP.sql            # Adds user_push_tokens table
│
├── .env.example                           # Copy to .env and fill in secrets
├── pubspec.yaml
└── build_run.ps1                          # Windows build helper script
```

> After changing any Isar model, regenerate schemas:
> ```bash
> dart run build_runner build --delete-conflicting-outputs
> ```

---

## 4. API Documentation

Services are the single point of data access. Each service is provided via Riverpod and receives `LocalDatabaseService` + `ConnectivityService` through its constructor, except singletons (`AuthService`, `ConnectivityService`, `NotificationService`).

The global Supabase client is accessed everywhere via:

```dart
final supabase = Supabase.instance.client;
```

**Offline behaviour summary:** Every write operation checks `ConnectivityService.isOnline` before hitting Supabase. When offline, actions are written to the local Isar database as optimistic records (prefixed `pending_`), queued as `IsarPendingAction` rows with serialized JSON payloads, and replayed in insertion order by `OfflineSyncService.syncAll()` when connectivity is restored (max 5 retries per action).

---

### 4.1 AuthService

```dart
class AuthService
```

#### Properties

| Property | Type | Description |
|---|---|---|
| `currentUser` | `User?` | Current Supabase Auth session user |
| `authStateChanges` | `Stream<AuthState>` | Stream of auth state change events |

---

#### `signUp()`

```dart
Future<AppUser> signUp({
  required String name,
  required String email,
  required String password,
  required String department,
  required String semester,
  required String studentId,
})
```

Calls `supabase.auth.signUp()`, then inserts into `users`. The DB trigger assigns the role before the insert completes. Caches the returned profile to `SharedPreferences`.

**Client-side validation (before any network call):**

| Field | Rule |
|---|---|
| `name` | Non-empty after trim |
| `password` | `length >= 8` |

**Domain validation (on email):**

Accepted suffixes: `.edu` · `.edu.bd` · `.ac.bd` · `.ac.uk` · `.ac.in`

**DB trigger validation (on `studentId`):**

| Pattern | Result |
|---|---|
| `^3[0-9]{7}$` | role = `student` |
| `^1[0-9]{7}$` | role = `faculty` |
| Anything else | `RAISE EXCEPTION` — sign-up rejected |

**Returns:** `Future<AppUser>`

**Example:**

```dart
final user = await authService.signUp(
  name: 'Rania Hossain',
  email: 'rania@uni.ac.bd',
  password: 'SecurePass1',
  department: 'Computer Science',
  semester: 'Spring 2025',
  studentId: 'CS-20182',
);
```

---

#### `signIn(email, password)`

```dart
Future<AppUser> signIn(String email, String password)
```

Validates university domain, then calls `supabase.auth.signInWithPassword()`. Fetches and caches the full profile on success.

**Returns:** `Future<AppUser>`

**Example:**

```dart
final user = await authService.signIn('rania@uni.ac.bd', 'SecurePass1');
```

---

#### `signOut()`

```dart
Future<void> signOut()
```

Calls `_clearCachedUser()` (removes `cached_user_profile` from `SharedPreferences`), then `supabase.auth.signOut()`.

---

#### `getUser(uid)`

```dart
Future<AppUser> getUser(String uid)
```

Fetches the `users` row by `id` and refreshes the local cache. On any network exception: loads the `SharedPreferences` cache and returns it if `cached.id == uid`, otherwise rethrows.

| Parameter | Type | Description |
|---|---|---|
| `uid` | `String` | Supabase Auth user UUID |

**Returns:** `Future<AppUser>`

> **Note:** Throws if the device is offline **and** no cached profile exists for the given `uid`.

---

#### `updateUser(uid, {name, department, semester})`

```dart
Future<void> updateUser(String uid, {String? name, String? department, String? semester})
```

Builds a map of non-null fields and calls `supabase.from('users').update(updates).eq('id', uid)`. Refreshes the local cache afterward.

| Parameter | Type | Description |
|---|---|---|
| `uid` | `String` | User UUID |
| `name` | `String?` | New display name (optional) |
| `department` | `String?` | New department (optional) |
| `semester` | `String?` | New semester (optional) |

---

#### `sendPasswordReset(email)`

```dart
Future<void> sendPasswordReset(String email)
```

Validates university domain, then calls `supabase.auth.resetPasswordForEmail(email)`.

---

#### `friendlyAuthError(e)`

```dart
String friendlyAuthError(Object e)
```

Normalizes raw Supabase/Dart auth exceptions into user-readable strings.

| Raw error contains | Shown to user |
|---|---|
| `over_email_send_rate_limit` / `429` | `"Too many attempts. Please wait 60 seconds and try again."` |
| `User already registered` | `"An account with this email already exists. Try signing in instead."` |
| `Invalid login credentials` | `"Incorrect email or password. Please try again."` |
| `Email not confirmed` | `"Please confirm your email first. Check your inbox for a verification link."` |
| `SocketException` / `NetworkException` | `"No internet connection. Check your WiFi or mobile data."` |
| `weak_password` | `"Password is too weak. Use at least 8 characters."` |
| Invalid domain (checked before call) | `"Must be a university email (e.g. .edu, .edu.bd, .ac.bd)"` |

---

#### `AppUser` model

```dart
class AppUser {
  final String id;                            // UUID — mirrors auth.users.id
  final String name;
  final String email;
  final String department;
  final String semester;
  final String studentId;
  final String role;                          // "student" | "faculty"
  final String? photoUrl;
  final List<String> bookmarkedAnnouncements; // UUID[]
  final List<String> rsvpedEvents;            // UUID[]

  String get uid => id;                       // alias used across the codebase
}
```

---

### 4.2 AnnouncementService

```dart
class AnnouncementService {
  AnnouncementService(LocalDatabaseService db, ConnectivityService connectivity)
}
```

---

#### `getAnnouncements({String? type})`

```dart
Stream<List<Announcement>> getAnnouncements({String? type})
```

`type` values: `"Academic"` · `"Financial"` · `"General"` · `"Club"` · `null` / `"All"` (returns everything).

Realtime channel name: `announcements_<type>` or `announcements_all`. One channel per active filter to avoid subscription conflicts.

**Stream lifecycle:**

```
1. Emit getCachedAnnouncements(type) from Isar immediately
2. if offline → stop here
3. SELECT * FROM announcements ORDER BY posted_at DESC  (timeout 10 s)
4. cacheAnnouncements(results)  →  re-emit
5. Subscribe channel  →  on any postgres_changes:
       re-SELECT  →  cacheAnnouncements  →  re-emit
```

**Returns:** `Stream<List<Announcement>>`

**Example:**

```dart
announcementService
  .getAnnouncements(type: 'Academic')
  .listen((list) => setState(() => _announcements = list));
```

---

#### `postAnnouncement({title, content, postedBy, postedById, type})`

```dart
Future<void> postAnnouncement({
  required String title,
  required String content,
  required String postedBy,
  required String postedById,
  required String type,
})
```

Throws `"Title cannot be empty"` or `"Content cannot be empty"` before any network call.

**Online:** `INSERT INTO announcements` → `NotificationService.send(type: 'announcement', excludeUserId: postedById)`

**Offline:** enqueue `IsarPendingAction(actionType: 'post_announcement', payloadJson: {...})` → insert optimistic `IsarAnnouncement(remoteId: 'pending_<ms>')` into Isar

| Parameter | Type | Description |
|---|---|---|
| `title` | `String` | Headline-cannot be empty |
| `content` | `String` | Full body text-cannot be empty |
| `postedBy` | `String` | Poster's display name |
| `postedById` | `String` | Poster's UUID (excluded from push notification) |
| `type` | `String` | `'Academic'` · `'Financial'` · `'General'` · `'Club'` |

---

#### `bookmarkToggle(userId, announcementId, add)`

```dart
Future<void> bookmarkToggle(String userId, String announcementId, bool add)
```

**Online:** `supabase.rpc('append_bookmark' | 'remove_bookmark', {user_id, ann_id})` → `updateAnnouncementBookmark(remoteId, add)` in Isar

**Offline:** `updateAnnouncementBookmark(remoteId, add)` only no server call, no pending action. State will reconcile on next full fetch.

| Parameter | Type | Description |
|---|---|---|
| `userId` | `String` | UUID of the user |
| `announcementId` | `String` | UUID of the announcement |
| `add` | `bool` | `true` to bookmark, `false` to remove |

---

#### `deleteAnnouncement(id)`

```dart
Future<void> deleteAnnouncement(String id)
```

`deleteAnnouncement(id)` on Isar (sets `isDeleted = true`) always runs first.

**Online:** `DELETE FROM announcements WHERE id = id`

**Offline:** enqueue `IsarPendingAction(actionType: 'delete_announcement', payloadJson: {id})`

---

#### `syncDeletions()`

```dart
Future<void> syncDeletions()
```

Replays queued announcement deletions against Supabase. Called by `OfflineSyncService` when connectivity is restored. No-op when offline.

---

#### `Announcement` model

```dart
class Announcement {
  final String id;
  final String title;
  final String content;
  final String postedBy;     // display name
  final String postedById;   // FK → users.id
  final DateTime postedAt;
  final String type;         // "Academic" | "Financial" | "General" | "Club"
  bool isBookmarked;         // resolved at emit time from user.bookmarkedAnnouncements
}
```

---

### 4.3 EventService

```dart
class EventService {
  EventService(LocalDatabaseService db, ConnectivityService connectivity)
}
```

---

#### `getEvents()`

```dart
Stream<List<Event>> getEvents()
```

Sorted by `date ASC`. Realtime channel: `events_changes`. Same three-tier pattern as announcements.

`isRSVPed` on each `Event` is resolved client-side from `user.rsvpedEvents` at the point the stream is consumed, the field is not in the DB row.

**Returns:** `Stream<List<Event>>`

---

#### `createEvent({title, description, category, location, date, time, organizer, organizerId})`

```dart
Future<void> createEvent({
  required String title,
  required String description,
  required String category,
  required String location,
  required DateTime date,
  required String time,
  required String organizer,
  required String organizerId,
})
```

`image_color` is picked deterministically: `colors[DateTime.now().millisecond % colors.length]` where `colors = ['1A56DB', '0E9F6E', 'E3A008', 'E02424', '9061F9', '3F83F8']`.

Throws `"Title required"` before any network call.

**Online:** `INSERT INTO events` → `NotificationService.send(type: 'event', excludeUserId: organizerId)`

**Offline:** enqueue `IsarPendingAction(actionType: 'create_event')` → insert optimistic `IsarEvent(remoteId: 'pending_<ms>')`

| Parameter | Type | Description |
|---|---|---|
| `title` | `String` | Event title — cannot be empty |
| `description` | `String` | Full description |
| `category` | `String` | e.g. `'Academic'`, `'Social'`, `'Sports'` |
| `location` | `String` | Venue name or address |
| `date` | `DateTime` | Event date |
| `time` | `String` | Human-readable string, e.g. `'3:00 PM'` |
| `organizer` | `String` | Organizer display name |
| `organizerId` | `String` | Organizer UUID (excluded from push notification) |

---

#### `rsvpEvent(eventId, userId, going)`

```dart
Future<void> rsvpEvent(String eventId, String userId, bool going)
```

**Online:** `supabase.rpc('toggle_rsvp', {p_event_id, p_user_id, p_going})`-atomically updates `users.rsvped_events[]` and `events.attendees`

**Offline:** `updateEventRsvp(eventId, going)` on Isar (immediate UI toggle) → enqueue `IsarPendingAction(actionType: 'rsvp_event', payloadJson: {event_id, user_id, going})`

---

#### `deleteEvent(id)`

```dart
Future<void> deleteEvent(String id)
```

Soft-deletes from Isar immediately. Online: `DELETE FROM events`. Offline: enqueue `IsarPendingAction(actionType: 'delete_event')`.

---

#### `Event` model

```dart
class Event {
  final String id;
  final String title;
  final String description;
  final String category;
  final String location;
  final DateTime date;
  final String time;           // human-readable e.g. "2:00 PM"
  final int attendees;         // managed by toggle_rsvp RPC
  final String organizer;      // display name
  final String organizerId;    // FK → users.id
  final String imageColor;     // hex string without '#', e.g. "1A56DB"
  final DateTime createdAt;
  bool isRSVPed;               // resolved client-side from user.rsvpedEvents, not a DB column
}
```

---

### 4.4 ResourceService

```dart
class ResourceService {
  static const _maxFileSizeBytes = 10 * 1024 * 1024;   // 10 MB
  static const _allowedExts = ['pdf','doc','docx','ppt','pptx','jpg','jpeg','png'];

  ResourceService(LocalDatabaseService db, ConnectivityService connectivity)
}
```

---

#### `getResources({String? department, String? type})`

```dart
Stream<List<Resource>> getResources({String? department, String? type})
```

Sorted by `uploaded_at DESC`. Filtering is applied client-side after the Supabase fetch (not via query params). Realtime channel name appends a millisecond timestamp to prevent stale subscription conflicts: `resources_<dept>_<type>_<ms>`.

| Parameter | Type | Description |
|---|---|---|
| `department` | `String?` | Department filter. Pass `'All'` or `null` to skip. |
| `type` | `String?` | File type filter: `'PDF'`, `'DOC'`, `'PPT'`, `'JPG'`, etc. |

**Returns:** `Stream<List<Resource>>`

---

#### `uploadResource({file, title, subject, department, semester, type, uploadedBy, uploadedById})`

```dart
Future<void> uploadResource({
  required File file,
  required String title,
  required String subject,
  required String department,
  required String semester,
  required String type,
  required String uploadedBy,
  required String uploadedById,
})
```

**Validation (throws before any I/O):**

| Check | Throws |
|---|---|
| `bytes.length > 10 MB` | `"File too large. Maximum size is 10 MB."` |
| Extension not in allowed list | `"File type not allowed. Use PDF, DOCX, PPT, or image files."` |
| `title.trim().isEmpty` | `"Title required"` |

**Online path:**

```
Storage path: resources/<uploadedById>/<timestamp>.<ext>
supabase.storage.from('resources').uploadBinary(storagePath, bytes)
url = supabase.storage.from('resources').getPublicUrl(storagePath)
INSERT INTO resources { title, subject, department, semester, type,
                        file_url, storage_path, size, uploaded_by,
                        uploaded_by_id, icon_color }
NotificationService.send(type: 'resource', excludeUserId: uploadedById)
```

**Offline path:**

```
savedFile = <appDocuments>/unisync_pending_uploads/pending_<ms>.<ext>
file.writeAsBytes(bytes)
enqueuePendingAction(actionType: 'upload_resource',
  payload: { local_file_path, ext, title, subject, department,
             semester, type, uploaded_by, uploaded_by_id, icon_color })
cacheResources([optimistic IsarResource(remoteId: 'pending_<ms>', fileUrl: savedFile.path)])
```

---

#### `incrementDownloads(id)`

```dart
Future<void> incrementDownloads(String id)
```

`supabase.rpc('increment_downloads', {resource_id: id})`. No-op when offline.

---

#### `rateResource(id, newRating)`

```dart
Future<void> rateResource(String id, double newRating)
```

`supabase.rpc('rate_resource', {p_resource_id: id, p_rating: newRating})`. The RPC computes:

```sql
new_avg = ((old_rating * old_count) + p_rating) / (old_count + 1)
```

No-op when offline.

---

#### `deleteResource(id, storagePath)`

```dart
Future<void> deleteResource(String id, String storagePath)
```

`deleteResource(id)` on Isar always runs first (immediate UI removal).

**Online:** `storage.from('resources').remove([storagePath])` → `DELETE FROM resources WHERE id = id`

**Offline:** enqueue `IsarPendingAction(actionType: 'delete_resource', payload: {id, storage_path})`- skipped entirely if `id.startsWith('pending_')` since the file never reached the server.

---

#### `Resource` model

```dart
class Resource {
  final String id;
  final String title;
  final String subject;
  final String department;
  final String semester;
  final String type;          // uppercase: "PDF" | "DOC" | "PPT" | "JPG" etc.
  final String fileUrl;       // Supabase Storage public URL
  final String storagePath;   // internal path needed for deletion
  final String size;          // human-readable e.g. "2048 KB"
  final int downloads;
  final double rating;        // running average, 0–5
  final int ratingCount;
  final String uploadedBy;    // display name
  final String uploadedById;  // FK → users.id
  final DateTime uploadedAt;
  final String iconColor;     // hex string without '#' for card icon
  bool isBookmarked;          // local-only, managed by MarkingService
}
```

---

### 4.5 ChatService

```dart
class ChatService {
  static const _maxMessageLength = 2000;

  ChatService(LocalDatabaseService db, ConnectivityService connectivity)
}
```

---

#### `getRooms(userId)`

```dart
Stream<List<ChatRoom>> getRooms(String userId)
```

Emits Isar cache first. Then fetches all `chat_rooms` ordered by `last_message_time DESC`, filters client-side to `member_ids.contains(userId)`, deduplicates by `room.id`. Subscribes to `chat_rooms_<userId>` Realtime channel.

Uses `select()` + Realtime instead of `.stream()` to prevent infinite shimmer on carrier-NAT WebSocket failures.

---

#### `getRoomsWithUnread(userId)`

```dart
Stream<List<ChatRoom>> getRoomsWithUnread(String userId)
```

Wraps `getRooms()`. For each emitted list:

1. Fetch `photo_url` for all member IDs via `SELECT id, photo_url FROM users WHERE id IN (...)`-one batched call, cached in a `Map<String, String?>`
2. For each room, read `last_seen_<roomId>` from `SharedPreferences`
3. Count messages newer than that timestamp not sent by `userId`- from Supabase (online) or Isar (offline)
4. Attach `memberPhotoUrls` and `unreadCount` to each `ChatRoom`

**Returns:** `Stream<List<ChatRoom>>`

---

#### `getMessages(roomId)`

```dart
Stream<List<ChatMessage>> getMessages(String roomId)
```

Emits Isar cache first (includes `pending_` optimistic messages). Then `SELECT * FROM chat_messages WHERE room_id = roomId ORDER BY created_at ASC`. Subscribes to Realtime INSERT events filtered by `room_id` on channel `room_<roomId>`.

On each fresh server fetch, calls `removeSyncedOptimisticMessages(roomId, serverContents)` to delete `pending_` Isar entries whose content matches a real server message.

**Returns:** `Stream<List<ChatMessage>>`

---

#### `sendMessage({roomId, senderId, senderName, content})`

```dart
Future<void> sendMessage({
  required String roomId,
  required String senderId,
  required String senderName,
  required String content,
})
```

Content is trimmed then truncated to `_maxMessageLength` (2000) if needed. Empty strings are silently ignored.

**Online:**

```
Verify senderId in chat_rooms.member_ids  (throws if not a member or room missing)
INSERT INTO chat_messages { room_id, sender_id, sender_name, content, created_at }
UPDATE chat_rooms SET last_message = preview, last_message_time = now WHERE id = roomId
NotificationService.send(type: 'chat', title: '💬 $senderName',
                          body: content[:80], excludeUserId: senderId)
```

**Offline:**

```
tempId = 'pending_<ms>_<senderId>'
cacheMessages([IsarChatMessage(remoteId: tempId, ...)])   // shows immediately
enqueuePendingAction(actionType: 'send_message',
  payload: { room_id, sender_id, sender_name, content, created_at, local_temp_id: tempId })
```

**Throws:** `'Chat room not found.'` or `'You are not a member of this chat.'`

| Parameter | Type | Description |
|---|---|---|
| `roomId` | `String` | Target chat room UUID |
| `senderId` | `String` | Sender's user UUID |
| `senderName` | `String` | Sender's display name |
| `content` | `String` | Message text — truncated to 2000 chars |

---

#### `createRoom({name, isGroup, memberIds, memberNames, createdById})`

```dart
Future<ChatRoom> createRoom({
  required String name,
  required bool isGroup,
  required List<String> memberIds,
  required List<String> memberNames,
  required String createdById,
})
```

Throws immediately if offline — room creation requires a live connection.

For non-group rooms with exactly 2 members: queries `chat_rooms` for an existing room where `is_group = false` and `member_ids @> memberIds`. Returns existing room if found; otherwise inserts a new one.

`avatar_color` is assigned from palette using `DateTime.now().millisecond % colors.length`.

**Returns:** `Future<ChatRoom>`

| Parameter | Type | Description |
|---|---|---|
| `name` | `String` | Group name (for DMs, either user's name) |
| `isGroup` | `bool` | `true` for group chat, `false` for DM |
| `memberIds` | `List<String>` | User UUIDs — must include the creator |
| `memberNames` | `List<String>` | Display names, parallel to `memberIds` |
| `createdById` | `String` | UUID of the creating user |

---

#### `markRoomAsRead(roomId)`

```dart
Future<void> markRoomAsRead(String roomId)
```

`SharedPreferences.setString('last_seen_$roomId', DateTime.now().toIso8601String())`. Resets unread count for that room.

---

#### `getUnreadCount(roomId)`

```dart
Future<int> getUnreadCount(String roomId)
```

Reads `last_seen_<roomId>` from `SharedPreferences` and counts messages newer than that timestamp not sent by the current user. Uses Supabase when online, Isar cache when offline.

---

#### `joinPresence(userId, userName)` / `leavePresence()`

```dart
void joinPresence(String userId, String userName)
void leavePresence()
Stream<Set<String>> onlineUserIds()
```

`joinPresence` subscribes to the `global_presence` channel, calls `channel.track({user_id, name})` once subscribed. `leavePresence` calls `channel.untrack()` then removes the channel.

`onlineStream` (`Stream<Set<String>>`) emits the current set of online user IDs on every `presenceSync`, `presenceJoin`, `presenceLeave` event.

Both are no-ops if offline.

**Example:**

```dart
// Join on login
chatService.joinPresence(user.id, user.name);

// Listen for online users
chatService.onlineUserIds().listen((ids) {
  setState(() => _onlineIds = ids);
});

// Leave on logout
chatService.leavePresence();
```

---

#### `deleteMessage(messageId)`

```dart
Future<void> deleteMessage(String messageId)
```

Soft-deletes from Isar immediately. Online: `DELETE FROM chat_messages WHERE id = messageId`. Offline: enqueue `IsarPendingAction(actionType: 'delete_message')`- only if `!messageId.startsWith('pending_')` (pending messages never existed on the server).

---

#### `ChatRoom` model

```dart
class ChatRoom {
  final String id;
  final String name;
  final String lastMessage;
  final DateTime lastMessageTime;
  final bool isGroup;
  final List<String> memberIds;
  final List<String> memberNames;
  List<String?> memberPhotoUrls; // runtime only — not in DB, populated by ChatService
  final String avatarColor;      // hex without '#'
  int unreadCount;               // computed by getRoomsWithUnread()

  // DM helpers — return the other person's data when isGroup = false
  String displayName(String currentUserId)
  String displayInitial(String currentUserId)
  String? displayPhotoUrl(String currentUserId)
}
```

---

#### `ChatMessage` model

```dart
class ChatMessage {
  final String id;          // UUID, or "pending_<ms>_<uid>" for offline messages
  final String roomId;
  final String senderId;
  final String senderName;
  final String content;     // 1–2000 chars (DB check constraint)
  final DateTime timestamp; // maps to created_at
}
```

---

### 4.6 ProfileService

```dart
class ProfileService {
  static const _maxAvatarBytes = 3 * 1024 * 1024;  // 3 MB
  static const _allowedExts = ['jpg', 'jpeg', 'png', 'webp'];
}
```

---

#### `uploadProfilePhoto(userId, file)`

```dart
Future<String> uploadProfilePhoto(String userId, File file)
```

Validates size (throws `"Image too large. Maximum size is 3 MB."`) and extension (throws `"Only JPG, PNG, or WEBP images are allowed."`).

Uploads to `avatars/<userId>.<ext>` with `FileOptions(upsert: true)` so repeated uploads overwrite the previous file. Then calls:

```dart
supabase.rpc('update_photo_url', params: {
  'p_user_id': userId,    // TEXT — RPC casts to UUID internally
  'p_photo_url': url,
})
```

This RPC exists specifically because direct `.update({'photo_url': url}).eq('id', userId)` from Dart throws `operator does not exist: uuid = text`.

**Returns:** `Future<String>`- public Supabase Storage URL

---

#### `searchUsers(query, {required String excludeId})`

```dart
Future<List<AppUser>> searchUsers(String query, {required String excludeId})
```

Returns `[]` if `query.trim().length < 2`.

```sql
SELECT id, name, email, department, semester, photo_url, role
FROM users
WHERE name ILIKE '%$query%'
  AND id != excludeId
LIMIT 20
```

Never returns `student_id` or any sensitive column.

| Parameter | Type | Description |
|---|---|---|
| `query` | `String` | Search string- minimum 2 characters |
| `excludeId` | `String` | UUID of current user (excluded from results) |

**Returns:** `Future<List<AppUser>>`

---

### 4.7 NotificationService

```dart
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();  // singleton
}
```

Must be initialized after `Firebase.initializeApp()`.

---

#### `initialize(oneSignalAppId)`

```dart
Future<void> initialize(String oneSignalAppId)
```

Initialization sequence:

```
OneSignal.Debug.setLogLevel(OSLogLevel.verbose)   // remove in production
OneSignal.initialize(oneSignalAppId)
OneSignal.Notifications.requestPermission(true)   // shows system dialog on Android 13+
OneSignal.Notifications.addClickListener(...)     // data['type'] for future routing
_savePlayerId()
OneSignal.User.pushSubscription.addObserver(...)  // re-upload on token rotation
```

`_savePlayerId()` also listens to `supabase.auth.onAuthStateChange`-whenever a session appears, it calls `_uploadPlayerId(currentId)` and `uploadPendingToken()`.

---

#### `uploadPendingToken()`

```dart
Future<void> uploadPendingToken()
```

Called from `LoginScreen` after successful sign-in and from `_AuthGate` when an existing session is detected at startup.

```
OneSignal.login(userId)                           // sets external ID = Supabase UID
liveId = OneSignal.User.pushSubscription.id
_uploadPlayerId(liveId)
pendingId = SharedPreferences.getString('pending_onesignal_id')
if pendingId != null && pendingId != liveId:
    _uploadPlayerId(pendingId)
SharedPreferences.remove('pending_onesignal_id')
```

`_uploadPlayerId` upserts into `user_push_tokens(user_id, player_id, updated_at)` with `onConflict: 'user_id'`. If the user is not yet authenticated, it saves to `SharedPreferences` under `pending_onesignal_id` instead.

---

#### `send()`-static

```dart
static Future<void> send({
  required String type,      // "announcement" | "event" | "chat" | "resource"
  required String title,
  required String body,
  String? excludeUserId,
})
```

Calls `supabase.functions.invoke('send-notification', body: {...})`. Errors are caught and printed-never rethrown. Called internally by `AnnouncementService`, `EventService`, `ChatService`, and `ResourceService` after every successful write.

| Parameter | Type | Description |
|---|---|---|
| `type` | `String` | `'announcement'` · `'event'` · `'chat'` · `'resource'` |
| `title` | `String` | Push notification title |
| `body` | `String` | Push notification body |
| `excludeUserId` | `String?` | User UUID to exclude from broadcast (e.g. the sender) |

**Example:**

```dart
NotificationService.send(
  type: 'announcement',
  title: '📢 New Announcement',
  body: announcement.title,
  excludeUserId: currentUser.id,
);
```

---

### 4.8 ConnectivityService

```dart
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;   // singleton

  bool get isOnline
  bool get isOffline
  void Function()? onConnectionRestored
}
```

---

#### `initialize()`

```dart
Future<void> initialize()
```

`checkConnectivity()` → sets `_isOnline`. Subscribes to `onConnectivityChanged`. On every change:

```
wasOnline = _isOnline
_isOnline = _resultsToOnline(results)
if !wasOnline && _isOnline:
    onConnectionRestored?.call()
```

`_resultsToOnline` handles both `List<ConnectivityResult>` (v6.x) and single `ConnectivityResult` (older versions).

`onConnectionRestored` is assigned in `main.dart`. Wire `OfflineSyncService.syncAll()` here to enable full auto-sync on reconnection:

```dart
connectivityService.onConnectionRestored = () async {
  final synced = await offlineSyncService.syncAll();
  print('Synced $synced pending actions');
};
```

---

### 4.9 OfflineSyncService

```dart
class OfflineSyncService {
  OfflineSyncService(LocalDatabaseService db, ConnectivityService connectivity)
}
```

Central offline-sync engine. When the device comes back online, `syncAll()` replays every pending `IsarPendingAction` against Supabase in insertion order.

---

#### `syncAll()`

```dart
Future<int> syncAll()
```

Returns immediately with `0` if offline. Fetches all `IsarPendingAction` where `isSynced == false`, sorted by `createdAt` ascending.

For each action:

```
if retryCount >= 5:
    markActionSynced(id)   // abandon — unblocks the queue
    continue

try:
    _replay(action)
    markActionSynced(id)
    synced++
catch:
    incrementActionRetry(id)

clearSyncedActions()       // prune completed records from Isar
return synced
```

**Returns:** `Future<int>`- count of successfully synced actions

---

#### `pendingCount()`

```dart
Future<int> pendingCount()
```

Returns count of unsynced `IsarPendingAction` records. Useful for a UI badge.

---

#### Replay dispatch table

| `actionType` | Server operation |
|---|---|
| `send_message` | Verify membership → `INSERT INTO chat_messages` → update `chat_rooms.last_message` → `NotificationService.send()` → delete local `pending_` Isar entry |
| `post_announcement` | `INSERT INTO announcements` → `NotificationService.send()` |
| `create_event` | `INSERT INTO events` → `NotificationService.send()` |
| `upload_resource` | Read file from `local_file_path` → `storage.uploadBinary()` → `INSERT INTO resources` → `NotificationService.send()` |
| `rsvp_event` | `supabase.rpc('toggle_rsvp', {event_id, user_id, going})` |
| `delete_message` | `DELETE FROM chat_messages WHERE id = ?` |
| `delete_announcement` | `DELETE FROM announcements WHERE id = ?` |
| `delete_event` | `DELETE FROM events WHERE id = ?` |
| `delete_resource` | `storage.remove([storage_path])` → `DELETE FROM resources WHERE id = ?` |

---

#### `IsarPendingAction` schema

```dart
@collection
class IsarPendingAction {
  Id? id;                  // Isar auto-increment — determines replay order
  late String actionType;
  late String payloadJson; // JSON-encoded fields needed to replay
  late DateTime createdAt;
  late int retryCount;     // incremented on each failure; abandoned at 5
  late bool isSynced;      // true after successful replay
  late String localTempId; // "pending_<ms>" — identifies the optimistic UI item
}
```

---

### 4.10 LocalDatabaseService

```dart
class LocalDatabaseService {
  static Future<void> initialize()  // opens unisync_db with 6 collections
  static Future<void> close()
}
```

Isar database name: `unisync_db`. Directory: `getApplicationDocumentsDirectory()`.

Collections: `IsarAnnouncement`, `IsarEvent`, `IsarChatRoom`, `IsarChatMessage`, `IsarResource`, `IsarPendingAction`.

**Upsert pattern** (same for all collections — announcements shown as example):

```dart
final existing = await isar.isarAnnouncements
    .filter().remoteIdEqualTo(ann.remoteId).findFirst();
if (existing != null) {
  ann.id = existing.id;
  ann.isBookmarked = existing.isBookmarked;  // preserve local-only field
}
ann.cachedAt = DateTime.now();
await isar.isarAnnouncements.put(ann);
```

**Local-only fields preserved per collection:**

| Collection | Preserved fields |
|---|---|
| `IsarAnnouncement` | `isBookmarked`, `isDeleted` |
| `IsarEvent` | `isRSVPed`, `isDeleted` |
| `IsarChatRoom` | `isDeleted` |
| `IsarChatMessage` | `isDeleted` |
| `IsarResource` | `isBookmarked`, `isDeleted` |

**All methods:**

| Method | Description |
|---|---|
| `cacheAnnouncements(list)` | Upsert by `remoteId`, preserve `isBookmarked` |
| `getCachedAnnouncements({type})` | Filter `isDeleted = false`, optionally filter by type |
| `updateAnnouncementBookmark(remoteId, bool)` | Set `isBookmarked` on matching record |
| `deleteAnnouncement(remoteId)` | Soft-delete: set `isDeleted = true` |
| `cacheEvents(list)` | Upsert by `remoteId`, preserve `isRSVPed` |
| `getCachedEvents()` | Filter `isDeleted = false` |
| `updateEventRsvp(eventId, bool)` | Set `isRSVPed` on matching record |
| `cacheChatRooms(list)` | Upsert by `remoteId` |
| `getCachedChatRooms()` | Filter `isDeleted = false` |
| `cacheMessages(list)` | Upsert by `remoteId` |
| `getCachedMessages(roomId)` | Filter by `roomId` and `isDeleted = false` |
| `removeSyncedOptimisticMessages(roomId, contents)` | Delete `pending_` messages whose content is in `contents` |
| `cacheResources(list)` | Upsert by `remoteId`, preserve `isBookmarked` |
| `getCachedResources({department, type})` | Filter `isDeleted = false`, optional dept/type filter |
| `updateResourceBookmark(remoteId, bool)` | Set `isBookmarked` |
| `getBookmarkedResources()` | `isDeleted = false AND isBookmarked = true` |
| `enqueuePendingAction(actionType, payloadJson, localTempId)` | Insert new `IsarPendingAction` |
| `getPendingActions()` | All `isSynced = false`, sorted by `createdAt` ASC |
| `markActionSynced(id)` | Set `isSynced = true` |
| `incrementActionRetry(id)` | `retryCount += 1` |
| `clearSyncedActions()` | Hard-delete all `isSynced = true` records |
| `pendingActionCount()` | Count of `isSynced = false` |
| `getDeletedItems()` | Returns `{announcements, events, messages, resources}` soft-deleted `remoteId` lists |
| `clearAllCache()` | Hard-clear all collections except `IsarPendingAction` |

---

### 4.11 MarkingService

```dart
class MarkingService {
  MarkingService(LocalDatabaseService db, ConnectivityService connectivity)
}
```

Handles resource bookmarking with optimistic local updates and background server sync.

---

#### `toggleResourceBookmark(resourceId, shouldBookmark)`

```dart
Future<void> toggleResourceBookmark(String resourceId, bool shouldBookmark)
```

Optimistic update to Isar first (`updateResourceBookmark(resourceId, shouldBookmark)`), then upserts to the `resource_bookmarks` Supabase table if online. If the server call fails, the local state is preserved and a warning is logged.

| Parameter | Type | Description |
|---|---|---|
| `resourceId` | `String` | UUID of the resource |
| `shouldBookmark` | `bool` | `true` to bookmark, `false` to remove |

---

#### `getBookmarkedResources()`

```dart
Future<List<IsarResource>> getBookmarkedResources()
```

Returns all locally bookmarked resources from the Isar cache (`isDeleted = false AND isBookmarked = true`).

---

#### `syncBookmarks()`

```dart
Future<void> syncBookmarks()
```

Upserts all locally bookmarked resources to `resource_bookmarks` on Supabase. Called when connectivity is restored. No-op when offline.

---

### 4.12 Edge Function — send-notification

**File:** `supabase/functions/send-notification/index.ts`  
**Runtime:** Deno on Supabase Edge Functions

Receives a POST from `supabase.functions.invoke()`, queries Supabase for target user IDs, and calls the OneSignal REST API.

---

#### Request body

```json
{
  "type":          "announcement",
  "title":         "📢 New Announcement",
  "body":          "Spring semester begins January 15th",
  "excludeUserId": "550e8400-e29b-41d4-a716-446655440000"
}
```

| Field | Type | Description |
|---|---|---|
| `type` | string | `"announcement"` · `"event"` · `"chat"` · `"resource"` — forwarded in `data` |
| `title` | string | Notification heading |
| `body` | string | Notification body text |
| `excludeUserId` | string? | Supabase UID of sender — excluded from recipients |

---

#### Function logic

```
1. Parse body: { type, title, body, excludeUserId }
2. Query: SELECT id FROM users [WHERE id != excludeUserId]
3. if users empty: return { sent: 0, reason: 'no users' }
4. externalIds = users.map(u => u.id)
5. POST https://onesignal.com/api/v1/notifications
     { app_id, include_aliases: { external_id: externalIds },
       target_channel: 'push',
       headings: { en: title }, contents: { en: body },
       data: { type }, priority: 10 }
6. return { sent: externalIds.length, result }
```

Targets by **external ID** (= Supabase UID, set via `OneSignal.login(uid)`) rather than subscription ID because subscription IDs can rotate while external IDs are stable.

---

#### Success response

```json
{ "sent": 42, "result": { "id": "...", "recipients": 42 } }
```

---

#### Required environment variables

| Variable | Where to find it |
|---|---|
| `ONESIGNAL_APP_ID` | OneSignal dashboard → Settings → Keys & IDs |
| `ONESIGNAL_REST_API_KEY` | OneSignal dashboard → Settings → Keys & IDs |
| `SUPABASE_URL` | Auto-injected by Supabase |
| `SUPABASE_SERVICE_ROLE_KEY` | Auto-injected by Supabase |

---

## 5. Database Schema

Run `SUPABASE_SETUP.sql` once in the Supabase SQL Editor. Everything tables, indexes, triggers, RPC functions, RLS policies, and Realtime publication is created idempotently (`CREATE TABLE IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`).

### Tables

```sql
users (
  id                       uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name                     text NOT NULL CHECK (char_length(trim(name)) >= 1),
  email                    text NOT NULL,
  department               text NOT NULL DEFAULT 'Computer Science',
  semester                 text NOT NULL DEFAULT '',
  student_id               text NOT NULL DEFAULT '',
  role                     text NOT NULL DEFAULT 'student' CHECK (role IN ('student','faculty')),
  photo_url                text,
  bookmarked_announcements uuid[] DEFAULT '{}',
  rsvped_events            uuid[] DEFAULT '{}',
  created_at               timestamptz DEFAULT NOW()
)

announcements (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title        text NOT NULL CHECK (char_length(trim(title)) >= 1),
  content      text NOT NULL CHECK (char_length(trim(content)) >= 1),
  posted_by    text NOT NULL,
  posted_by_id uuid REFERENCES users(id) ON DELETE SET NULL,
  posted_at    timestamptz DEFAULT NOW(),
  type         text NOT NULL DEFAULT 'General'
               CHECK (type IN ('Academic','Financial','General','Club'))
)

events (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title        text NOT NULL CHECK (char_length(trim(title)) >= 1),
  description  text NOT NULL DEFAULT '',
  category     text NOT NULL DEFAULT 'General',
  location     text NOT NULL DEFAULT '',
  date         timestamptz NOT NULL,
  time         text NOT NULL DEFAULT '',
  attendees    int NOT NULL DEFAULT 0 CHECK (attendees >= 0),
  organizer    text NOT NULL,
  organizer_id uuid REFERENCES users(id) ON DELETE SET NULL,
  image_color  text NOT NULL DEFAULT '1A56DB',
  created_at   timestamptz DEFAULT NOW()
)

resources (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title          text NOT NULL CHECK (char_length(trim(title)) >= 1),
  subject        text NOT NULL DEFAULT '',
  department     text NOT NULL DEFAULT '',
  semester       text NOT NULL DEFAULT '',
  type           text NOT NULL DEFAULT 'PDF',
  file_url       text NOT NULL,
  storage_path   text NOT NULL DEFAULT '',
  size           text NOT NULL DEFAULT '0 KB',
  downloads      int NOT NULL DEFAULT 0 CHECK (downloads >= 0),
  rating         float NOT NULL DEFAULT 0 CHECK (rating >= 0 AND rating <= 5),
  rating_count   int NOT NULL DEFAULT 0 CHECK (rating_count >= 0),
  uploaded_by    text NOT NULL,
  uploaded_by_id uuid REFERENCES users(id) ON DELETE SET NULL,
  uploaded_at    timestamptz DEFAULT NOW(),
  icon_color     text NOT NULL DEFAULT '1A56DB'
)

chat_rooms (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name              text NOT NULL CHECK (char_length(trim(name)) >= 1),
  last_message      text NOT NULL DEFAULT '',
  last_message_time timestamptz DEFAULT NOW(),
  is_group          boolean NOT NULL DEFAULT FALSE,
  member_ids        uuid[] NOT NULL DEFAULT '{}',
  member_names      text[] NOT NULL DEFAULT '{}',
  avatar_color      text NOT NULL DEFAULT '1A56DB'
)

chat_messages (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id     uuid NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
  sender_id   uuid REFERENCES users(id) ON DELETE SET NULL,
  sender_name text NOT NULL,
  content     text NOT NULL CHECK (char_length(trim(content)) >= 1
                               AND char_length(content) <= 2000),
  created_at  timestamptz DEFAULT NOW()
)
```

### Indexes

```sql
CREATE INDEX idx_events_date        ON events(date);
CREATE INDEX idx_announcements_date ON announcements(posted_at DESC);
CREATE INDEX idx_messages_room      ON chat_messages(room_id, created_at);
CREATE INDEX idx_resources_dept     ON resources(department);
```

### Role trigger

```sql
CREATE FUNCTION assign_role_from_id() RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF new.student_id ~ '^3[0-9]{7}$' THEN
    new.role := 'student';
  ELSIF new.student_id ~ '^1[0-9]{7}$' THEN
    new.role := 'faculty';
  ELSE
    RAISE EXCEPTION 'Invalid ID. Student IDs start with 3, Faculty IDs start with 1. Both must be exactly 8 digits.';
  END IF;
  RETURN new;
END;
$$;

CREATE TRIGGER trg_assign_role_from_id
  BEFORE INSERT ON users
  FOR EACH ROW EXECUTE FUNCTION assign_role_from_id();
```

### RPC functions

| Function | Signature | What it does |
|---|---|---|
| `append_bookmark` | `(user_id uuid, ann_id uuid)` | `array_remove` then `array_append` on `bookmarked_announcements[]` — deduplicates atomically |
| `remove_bookmark` | `(user_id uuid, ann_id uuid)` | `array_remove` from `bookmarked_announcements[]` |
| `toggle_rsvp` | `(p_event_id uuid, p_user_id uuid, p_going bool)` | Adds/removes from `rsvped_events[]` + increments/decrements `events.attendees` (floor 0) |
| `increment_downloads` | `(resource_id uuid)` | `downloads = downloads + 1` |
| `rate_resource` | `(p_resource_id uuid, p_rating float)` | Running average: `((old * count) + new) / (count + 1)` |
| `update_photo_url` | `(p_user_id text, p_photo_url text)` | Updates `photo_url`; accepts text and casts to uuid internally to avoid Dart client type mismatch |

### Row-Level Security

| Table | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| `users` | Any authenticated | Own row only | Own row only | — |
| `announcements` | Any authenticated | `faculty` role only | — | Own `posted_by_id` or `faculty` |
| `events` | Any authenticated | `faculty` role only | Any authenticated (for RSVP count) | Own `organizer_id` or `faculty` |
| `resources` | Any authenticated | Any authenticated | Any authenticated | Own `uploaded_by_id` or `faculty` |
| `chat_rooms` | `auth.uid() = ANY(member_ids)` | Any authenticated | Room members only | — |
| `chat_messages` | Room members only | `sender_id = auth.uid()` AND room member | — | — |

### Realtime publications

```sql
ALTER PUBLICATION supabase_realtime ADD TABLE announcements;
ALTER PUBLICATION supabase_realtime ADD TABLE events;
ALTER PUBLICATION supabase_realtime ADD TABLE chat_rooms;
ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE resources;
```

---

## 6. Tech Stack

| Layer | Technology | Version |
|---|---|---|
| Mobile framework | Flutter | 3.2.0+ |
| Language | Dart | ≥3.2.0 <4.0.0 |
| Backend | Supabase (PostgreSQL + Auth + Storage + Realtime) | flutter SDK 2.5.0 |
| Local database | Isar NoSQL | 3.1.0+ |
| State management | Flutter Riverpod | 2.6.1 |
| Push infra | Firebase Cloud Messaging | firebase_messaging 15.1.0 |
| Push management | OneSignal | onesignal_flutter 5.2.5 |
| Connectivity | connectivity_plus | 6.1.1 |
| Environment | flutter_dotenv | 5.1.0 |
| Edge Functions | Deno (TypeScript) | Supabase-managed |
| Fonts | google_fonts | 6.3.3 |
| Calendar widget | table_calendar | 3.1.3 |
| Image caching | cached_network_image | 3.4.1 |
| File picker | file_picker | 8.3.7 |
| Image picker | image_picker | 1.1.2 |
| Relative time | timeago | 3.7.0 |
| UUID generation | uuid | 4.5.1 |
| Preferences | shared_preferences | 2.3.2 |
