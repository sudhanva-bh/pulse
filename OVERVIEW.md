# Pulse — Project Overview & Implementation Plan

---

## Table of Contents

1. [What is Pulse?](#1-what-is-pulse)
2. [The Problem It Solves](#2-the-problem-it-solves)
3. [Core Architecture](#3-core-architecture)
4. [System Design Decisions](#4-system-design-decisions)
5. [Full Tech Stack](#5-full-tech-stack)
6. [Package Inventory & Purpose](#6-package-inventory--purpose)
7. [Feature Set](#7-feature-set)
8. [Data Models](#8-data-models)
9. [Message Lifecycle State Machine](#9-message-lifecycle-state-machine)
10. [Implementation Timeline](#10-implementation-timeline)
11. [Folder Structure](#11-folder-structure)
12. [Engineering Depth Checklist](#12-engineering-depth-checklist)
13. [Resume Positioning](#13-resume-positioning)

---

## 1. What is Pulse?

Pulse is an **offline-first Android messaging platform** that rethinks how mobile apps handle connectivity. While conventional messaging apps treat internet connectivity as a hard dependency — failing silently or showing error states when the network disappears — Pulse treats it as an optional transport layer.

Every message in Pulse is written to a local SQLite database the instant the user taps send. The UI updates immediately from that local source of truth. Network synchronisation happens in the background, independently, and transparently. The user never waits for a network round-trip to see their message appear.

When internet connectivity is completely unavailable — even for extended periods — Pulse activates a QR-based peer-to-peer LAN fallback. Two devices on the same WiFi network can exchange messages directly, without any server involvement, by scanning a QR code that establishes a one-time authenticated local socket connection.

Pulse is built as a portfolio project targeting SDE roles at product companies, and is engineered to demonstrate senior-level concerns: idempotent sync, process-death recovery, structured concurrency, schema migration, and production release rigour.

---

## 2. The Problem It Solves

### Connectivity is unreliable — apps pretend it isn't

Standard chat apps (WhatsApp, Telegram) are cloud-first: they make a network request to send a message, wait for a server acknowledgement, then update the UI. In poor or intermittent connectivity — which is the norm in many real-world environments — this means messages silently fail, the UI freezes, or the user is shown an error with no clear recovery path.

### What Pulse does differently

Pulse inverts this model:

- **Write locally first, always.** The database is the source of truth, not the server.
- **Sync is a background concern.** It happens when it can, retries when it can't, and never blocks the user.
- **Multiple transports, one abstraction.** WebSockets for real-time cloud delivery, REST for delta sync, and LAN sockets for peer-to-peer delivery — all behind a single transport interface.
- **Process death is not a failure mode.** WorkManager persists sync state across app kills, reboots, and OS-initiated terminations.

---

## 3. Core Architecture

```
┌─────────────────────────────────────────────┐
│                  Flutter UI                  │
│         (Riverpod streams from Drift)        │
└─────────────────┬───────────────────────────┘
                  │ reads / writes
┌─────────────────▼───────────────────────────┐
│            Repository Layer                  │
│   (MessageRepository, ConversationRepository)│
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│         Local Database — Drift/SQLite        │
│              (Source of Truth)               │
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│              Sync Engine                     │
│  ┌─────────────┐ ┌──────────┐ ┌──────────┐  │
│  │  WebSocket  │ │REST Sync │ │LAN Socket│  │
│  │  Transport  │ │Transport │ │Transport │  │
│  └──────┬──────┘ └────┬─────┘ └────┬─────┘  │
└─────────┼─────────────┼────────────┼─────────┘
          │             │            │
┌─────────▼─────────────▼────────────▼─────────┐
│              FastAPI Backend                  │
│         (PostgreSQL + SQLAlchemy)             │
└───────────────────────────────────────────────┘
```

### Key Architectural Principles

**Local Source of Truth** — The UI reads exclusively from SQLite via Drift streams. It never reads from the network directly. Network responses write into the local DB, and the UI picks up changes from the stream.

**Transport Abstraction** — WebSocket, REST sync, and LAN socket are all implementations of the same transport interface. The sync engine selects the appropriate one based on connectivity state, without the rest of the app knowing or caring.

**Idempotent Writes** — Every message carries a UUID generated on the client before sending. If the same message is synced twice (due to a retry), the backend's `INSERT ... ON CONFLICT DO UPDATE` prevents duplication. The operation is safe to repeat.

**Delta Sync** — The client stores a `last_sync_timestamp`. The `/sync` endpoint returns only records modified after that timestamp. Full re-sync is never required.

**Conflict Resolution** — Last Write Wins on `updated_at`. Simple, predictable, and correct for a two-party chat model.

---

## 4. System Design Decisions

### Why UUID on the client, not an auto-increment server ID?

If the server generates the ID, the client has no ID until the server responds. This means the message can't be stored locally with a stable identity before the network round-trip completes. Client-generated UUIDs allow immediate local storage, optimistic UI, and safe retry — all without waiting for any server response.

### Why Drift over Isar or sqflite directly?

Drift provides typed SQL queries, compile-time verification, and — critically — a first-class migration system. `schemaVersion` plus `onUpgrade` gives a real migration path without dropping and recreating tables. Isar is faster for some workloads but its migration story is weaker. Raw sqflite requires manual query strings with no type safety.

### Why WorkManager over Dart Isolates for background sync?

Dart Isolates are in-process — they die when the app process dies. WorkManager is an Android OS-level scheduler that survives app kills, device restarts, and Doze mode. For sync retries that must survive process death, WorkManager is the only correct choice on Android.

### Why FastAPI over Django or Node.js?

FastAPI has native async support, automatic OpenAPI documentation, and first-class Pydantic integration — validation, serialisation, and schema documentation come for free. It also has built-in WebSocket support with no additional libraries. For a solo portfolio project with a Python background, it is the highest-productivity choice.

### Why OAuth2 Password Flow over custom JWT auth?

FastAPI's `OAuth2PasswordBearer` and `OAuth2PasswordRequestForm` are built around the OAuth2 spec. Using them means the `/auth/login` endpoint is spec-compliant, FastAPI's interactive docs (`/docs`) support the Authorize button automatically, and the auth scheme is immediately recognisable to any engineer reviewing the code.

---

## 5. Full Tech Stack

### Backend
| Concern | Technology |
|---|---|
| API framework | FastAPI |
| Database | PostgreSQL 16 |
| ORM | SQLAlchemy |
| Migrations | Alembic |
| Auth | OAuth2 Password Flow + JWT (python-jose) |
| Password hashing | passlib (bcrypt) |
| Validation | Pydantic v2 |
| Containerisation | Docker + Docker Compose |
| Real-time | FastAPI WebSockets |

### Frontend (Android)
| Concern | Technology |
|---|---|
| Framework | Flutter (Android only) |
| State management | Riverpod |
| Local database | Drift (SQLite) |
| Navigation | GoRouter |
| Networking | Dio |
| Secure storage | flutter_secure_storage (Android Keystore) |
| Background sync | workmanager |
| Push notifications | Firebase Cloud Messaging (FCM) |
| Crash reporting | Firebase Crashlytics |
| Animations/loading | loading_animation_widget |
| Toast notifications | toastification |
| Icons | font_awesome_flutter |
| Data visualisation | cristalyse |
| Biometrics | local_auth |

---

## 6. Package Inventory & Purpose

### `loading_animation_widget`
Used throughout the app wherever an async operation is in progress and a spinner is insufficient. Specific usage points:
- Splash screen while session is being restored from Keystore
- Chat screen while the initial Drift stream is hydrating
- Sync status indicator in the app bar (subtle pulsing animation when background sync is active)
- QR LAN connection establishment screen while the socket handshake completes

The package provides a wide range of named animations. Pulse uses a consistent subset to maintain visual coherence — one animation style for loading states, one for processing states.

### `toastification`
Replaces all `SnackBar` usage. Provides non-blocking, positioned toast notifications for transient feedback. Specific usage points:
- Message send failure (network down, not queued yet)
- Sync completed after coming back online ("Messages delivered")
- QR LAN delivery success ("Messages sent via local network")
- Auth errors (wrong password, username taken)
- Token expired — prompt to re-login
- File transfer completion

Toastification's style, duration, and position are configured once in a central notification service, not inline at each call site. The toast type (success / error / warning / info) maps to the event category.

### `font_awesome_flutter`
Provides the icon set used throughout Pulse's UI. Flutter's built-in `Icons` class is limited in expressiveness. Font Awesome covers messaging-specific iconography cleanly. Specific usage points:
- Navigation bar icons (conversations, profile, settings)
- Message status icons (clock for pending, check for sent, double-check for delivered)
- QR scan icon on the LAN fallback screen
- Connection status indicator (WiFi, no WiFi, syncing)
- Attachment type indicators (image, file, location)
- Auth screen icons (user, lock, eye/eye-slash for password visibility)

### `cristalyse`
A grammar-of-graphics data visualisation library for Flutter. Used in Pulse's diagnostics/analytics screen — a developer-facing screen (hidden behind a settings toggle in production, visible during development) that surfaces real-time sync health metrics. Specific usage points:
- **Line chart**: message sync latency over time — plots the time between a message being written locally and being acknowledged by the server
- **Bar chart**: sync attempt outcomes grouped by transport type (WebSocket / REST / LAN)
- **Scatter plot**: message delivery timeline — one point per message, x-axis is `created_at`, y-axis is time to delivery
- **Area chart**: cumulative unsynced message count over a session

This screen serves two purposes: it provides genuine insight into the sync engine's behaviour during development, and it demonstrates that you understand how to build non-trivial UI features that go beyond standard chat app scope.

Cristalyse's grammar-of-graphics API means charts are built declaratively: `.data()` → `.mapping()` → `.geomLine()` → `.build()`. The interactive tooltip config is used to show per-point sync metadata on tap.

---

## 7. Feature Set

### Core Features (Must-ship)
- User registration and login with OAuth2 Password Flow
- Conversation list with last-message preview
- Real-time chat with WebSocket delivery
- Offline message queuing with automatic sync on reconnect
- QR-based LAN peer-to-peer message delivery
- Message status tracking: pending → sending → delivered → read → failed / queued
- Draft persistence across app kills
- Process-death recovery via WorkManager
- Push notifications via FCM with token rotation
- Full permission lifecycle handling (granted / denied / permanently denied / revoked)
- Biometric app lock
- Crash reporting via Firebase Crashlytics
- Staged rollout via Play Store internal → alpha tracks

### Secondary Features (Build if time permits)
- Read receipts
- Typing indicators
- Image sharing (cloud upload, LAN chunked transfer)
- Sync diagnostics screen (Cristalyse charts)
- Disappearing messages

### Explicitly Out of Scope
- iOS support
- Group chats (two-party only)
- End-to-end encryption (key management adds 2+ weeks)
- Video calling
- Message search

---

## 8. Data Models

### Backend (PostgreSQL / SQLAlchemy)

**users**
```
id                UUID          PK, client-generated
username          VARCHAR       UNIQUE, NOT NULL, indexed
password_hash     VARCHAR       NOT NULL
fcm_token         VARCHAR       NULLABLE
created_at        TIMESTAMP     server default
updated_at        TIMESTAMP     server default, on update
```

**messages**
```
id                UUID          PK, client-generated
conversation_id   VARCHAR       NOT NULL, indexed
sender_id         VARCHAR       NOT NULL, FK → users.id
content           TEXT          NOT NULL
status            VARCHAR       NOT NULL, default 'sent'
created_at        TIMESTAMP     NOT NULL (client timestamp)
updated_at        TIMESTAMP     NOT NULL (client timestamp)
synced_at         TIMESTAMP     server default (when server received it)
```

**conversations**
```
id                UUID          PK
participant_ids   VARCHAR[]     NOT NULL
created_at        TIMESTAMP     server default
last_message_at   TIMESTAMP     NULLABLE, updated on each message
```

### Frontend (SQLite / Drift)

**messages** (mirrors backend, adds local-only columns)
```
id                TEXT          PK
conversation_id   TEXT          NOT NULL
sender_id         TEXT          NOT NULL
content           TEXT          NOT NULL
status            TEXT          NOT NULL, default 'pending'
created_at        INTEGER       NOT NULL (stored as epoch ms)
updated_at        INTEGER       NOT NULL
synced_to_cloud   BOOLEAN       NOT NULL, default false
```

**conversations**
```
id                TEXT          PK
participant_ids   TEXT          NOT NULL (JSON encoded)
last_message_at   INTEGER       NULLABLE
created_at        INTEGER       NOT NULL
```

---

## 9. Message Lifecycle State Machine

```
User taps send
      │
      ▼
Generate UUID on device
      │
      ▼
Insert into Drift  ──────────────────────► UI updates instantly
  status: pending
      │
      ▼
  Connected?
  ┌───┴───┐
 YES      NO
  │        │
  ▼        ▼
WebSocket  status: queued
send       │
  │        └──► WorkManager schedules sync
  ▼                    │
Server ack?            │ (on connectivity restore)
  ┌──┴──┐             │
 YES    NO             ▼
  │      │         /sync endpoint
  │      │             │
  │      └──► retry    ▼
  │           (max 3)  Server writes
  │                    │
  ▼                    ▼
status: delivered  status: delivered
syncedToCloud: true

      │
      ▼
Recipient opens message
      │
      ▼
Read receipt sent via WebSocket
      │
      ▼
status: read

On permanent failure (3 retries exhausted):
      │
      ▼
status: failed
toastification error toast shown
Manual retry available
```

### QR LAN Branch (no internet on either device)

```
User has queued messages
      │
      ▼
Tap "Send via local network" button
      │
      ▼
Device A generates QR payload:
{ ip, port, one_time_token, expiry_timestamp }
      │
      ▼
Device B scans QR
      │
      ▼
TCP socket connection established
      │
      ▼
Token validated (one-use, expires in 60s)
      │
      ▼
Queued messages flushed over LAN socket
      │
      ▼
status: delivered_locally
      │
      ▼
(On internet restore) → /sync → cloud updated
```

---

## 10. Implementation Timeline

> **Assumptions**: 2–3 hours per day, Android only, 8 weeks total.
> Backend and Flutter tracks run in parallel within each week.

---

### Week 1 — Foundation Layer
**Theme**: Infrastructure that every subsequent week builds on. Nothing chat-related yet.

**Backend Tasks**
- Set up Docker Compose with FastAPI and PostgreSQL services
- Configure health-checked startup ordering (FastAPI waits for Postgres)
- Write SQLAlchemy models for `User` and `Message`
- Configure Alembic with `DATABASE_URL` from `.env` (not hardcoded in `alembic.ini`)
- Generate and apply the initial schema migration
- Write Pydantic v2 schemas with field validators (`UserRegister`, `UserResponse`, `TokenResponse`, `MessageCreate`, `MessageResponse`)
- Implement `security.py`: bcrypt password hashing and JWT encode/decode
- Implement `dependencies.py`: `get_current_user` using `OAuth2PasswordBearer`
- Implement auth router: `POST /auth/register`, `POST /auth/login` (OAuth2 form data), `GET /auth/me`
- Test all three endpoints in Postman — register (JSON), login (form data), me (Bearer token)
- Verify persistent volume: `docker compose down && docker compose up`, previously registered user still exists

**Flutter Tasks**
- Create `frontend/` directory inside the mono repo with `flutter create`
- Set up folder structure: `core/`, `features/auth/`, `features/chat/` (empty), `routing/`
- Add all dependencies to `pubspec.yaml`
- Set up Drift with `Messages` and `Conversations` tables, `schemaVersion: 1`, `onUpgrade` stubbed
- Run `build_runner` and commit generated files
- Implement `secure_storage.dart` wrapping `flutter_secure_storage` with `AndroidOptions(encryptedSharedPreferences: true)`
- Implement `api_client.dart` with Dio, `_AuthInterceptor` that auto-attaches JWT from Keystore
- Note: emulator uses `10.0.2.2` as the host machine's address, not `localhost`
- Implement `AuthRepository`: login (form-encoded), register, `isLoggedIn`, logout
- Implement `AuthNotifier` with sealed `AuthState`: initial / loading / authenticated / unauthenticated / error
- Implement `app_router.dart` with GoRouter — redirect logic driven by `authProvider`
- Implement splash screen that calls `checkSession()` on first frame
- Wire login and register screens to `AuthNotifier`
- Use `loading_animation_widget` on splash screen during session restore
- Use `toastification` for auth error feedback (wrong password, username taken, network failure)
- Use `font_awesome_flutter` for auth screen icons (user, lock, eye toggle)

**Week 1 Deliverable**: Login persists across force-stops. Cold start routes correctly. Docker stack starts cleanly from a fresh clone.

**Week 1 End Checklist**
- [ ] `docker compose up` works from a fresh clone, no extra steps
- [ ] Alembic `versions/` has one committed migration file
- [ ] `POST /auth/login` uses form data, not JSON
- [ ] JWT stored in Android Keystore
- [ ] Force-stop → reopen → routes to home (token found)
- [ ] `.env` is in `.gitignore`

---

### Week 2 — Local-First Chat UI
**Theme**: A fully working chat app that operates with zero network. No Dio or WebSocket code this week.

**Flutter Tasks**
- Create Drift DAOs: `MessageDao` and `ConversationDao`
  - `MessageDao`: `watchMessages(conversationId)` as a stream, `insertMessage`, `updateStatus`, `markSynced`, `upsertMessage`, `getUnsyncedMessages`
  - `ConversationDao`: `watchAllConversations` as a stream, `upsertConversation`, `updateLastMessage`
- Register DAOs in `AppDatabase`
- Re-run `build_runner` after DAO changes
- Create domain models: `Message` (with `MessageStatus` enum), `Conversation`
- Create `MessageRepository`: `watchMessages`, `sendMessage` (UUID generation, Drift insert, status: pending), `updateStatus`
- Create `ConversationRepository`: `watchConversations`, `upsertConversation`
- Add draft persistence to `SecureStorage`: `saveDraft`, `getDraft`, `clearDraft` keyed by conversation ID
- Create Riverpod providers: `appDatabaseProvider`, `messageDaoProvider`, `messageRepositoryProvider`, `messagesProvider` (StreamProvider.family), `conversationsProvider`
- Build `MessageBubble` widget: aligned left/right by sender, rounded corners, status icon in bottom-right
- Status icon mapping using `font_awesome_flutter`: clock (pending), check (sending), double-check (delivered), error (failed), schedule-send (queued)
- Build `MessageInput` widget: `TextEditingController` that loads draft on `initState`, saves draft on every change via listener, clears draft on send
- Build `ChatScreen`: `ListView.builder` (never `ListView` with a `children` list), driven by `messagesProvider(conversationId)`, `FutureBuilder` for current user ID to determine bubble alignment
- Build `ConversationListScreen`: `ListView.builder` driven by `conversationsProvider`, FAB to create test conversations
- Add `/chat/:conversationId` route to GoRouter
- Update `/home` route to point to `ConversationListScreen`
- Profile `ChatScreen` in Flutter DevTools — verify 60fps with 100+ messages before proceeding

**Week 2 Deliverable**: Chat works entirely offline. Messages appear instantly on send. Status shows pending. Draft survives force-stop. No jank.

**Week 2 End Checklist**
- [ ] UI driven by Drift stream — no `setState` for message list
- [ ] `ListView.builder` used throughout
- [ ] Tap send → message visible before any async work completes
- [ ] Type a draft, force-stop, reopen — draft restored
- [ ] 60fps confirmed in DevTools with 100+ messages
- [ ] Zero network code in this week's files

---

### Week 3 — WebSocket Real-Time Delivery
**Theme**: Two devices talking over the internet in real time. Backend and Flutter connect properly for the first time since auth.

**Backend Tasks**
- Add `POST /conversations` endpoint to create or fetch a conversation between two users
- Add `GET /conversations` endpoint — returns all conversations for the authenticated user
- Add `GET /conversations/{id}/messages` endpoint — returns message history for a conversation
- Implement WebSocket endpoint: `GET /ws/{user_id}` — authenticated via token query param (WebSocket headers are limited)
- Manage connected clients in a dictionary: `{user_id: WebSocket}`
- On message received via WebSocket: write to PostgreSQL, look up recipient's WebSocket, forward if connected
- Handle WebSocket disconnect cleanly — remove from connected clients dict
- Add `POST /messages` REST endpoint as fallback for when WebSocket is unavailable

**Flutter Tasks**
- Implement `WebSocketManager`: connects to `ws://host/ws/{userId}?token=...`, handles incoming message JSON, reconnects with exponential backoff (1s, 2s, 4s, 8s, cap at 60s)
- On incoming WebSocket message: parse, upsert into Drift via `MessageDao.upsertMessage`, update `ConversationDao.updateLastMessage`
- On send: attempt WebSocket send first → on success update status to `sending` → on server ack update to `delivered`
- Connection state enum: `connected / reconnecting / disconnected` — surfaced in chat screen app bar
- Use `font_awesome_flutter` WiFi/no-WiFi icon for connection state indicator
- Use `loading_animation_widget` during WebSocket reconnection (subtle, in app bar, not blocking)
- Implement typing indicator: send `{type: "typing", conversationId: ...}` event on text change with 2s debounce, show indicator in chat UI when received
- Wire up `GET /conversations` to `ConversationRepository` — real conversations from backend replace test FAB
- Wire up `GET /conversations/{id}/messages` for initial history load on chat screen open

**Week 3 Deliverable**: Two devices on the same network exchange messages in real time. Typing indicator works. Connection state is visible. Reconnection is automatic.

**Week 3 End Checklist**
- [ ] Two emulators (or emulator + physical device) exchange messages in real time
- [ ] Typing indicator appears and disappears correctly
- [ ] Kill the backend, revive it — Flutter reconnects automatically
- [ ] Conversation list updates when a new message arrives
- [ ] Connection state icon updates correctly

---

### Week 4 — Offline Sync Engine
**Theme**: The most important week. Offline messages deliver when connectivity returns. WorkManager survives process death.

**Backend Tasks**
- Implement `POST /sync` endpoint: accepts `last_sync_timestamp` and a list of locally-created messages; server performs `INSERT ... ON CONFLICT(id) DO UPDATE SET ...` for each; returns messages created by others since `last_sync_timestamp`
- The `ON CONFLICT DO UPDATE` is the idempotency guarantee — the same sync request can be sent multiple times safely
- Add conversation participants check — only sync messages for conversations the authenticated user is part of
- Validate `last_sync_timestamp` — reject obviously invalid values

**Flutter Tasks**
- Implement `SyncEngine` class: responsible for flushing the sync queue and processing server-returned messages
- Sync queue: all messages with `syncedToCloud: false` are the queue; `MessageDao.getUnsyncedMessages()` is the queue reader
- On sync: call `POST /sync` with `last_sync_timestamp` and all unsynced messages; on success, call `markSynced` for each; update `last_sync_timestamp` in `SecureStorage`; upsert server-returned messages into Drift
- Partial failure handling: if sync fails mid-way, the queue retains unsent messages and retries on the next cycle — no message is lost
- Retry logic: exponential backoff for failed sync attempts, max 3 retries before status → `failed`
- Implement `ConnectivityService`: watches network state, triggers `SyncEngine` on connectivity restore
- Implement WorkManager integration: register a periodic sync task (every 15 minutes, minimum interval Android allows) and a one-shot sync task triggered on connectivity change
- WorkManager constraints: `NetworkType.connected` — task only runs when internet is available, respects Doze mode
- On cold start: `SyncEngine.runOnStartup()` — checks for unsynced messages and triggers sync immediately
- Store `last_sync_timestamp` in `SecureStorage` — persists across kills
- Update message status flow: `queued` → WorkManager picks up → `sending` → server ack → `delivered`
- Use `toastification` success toast when sync completes after being offline ("Messages delivered")

**Week 4 End Checklist**
- [ ] Send 10 messages offline, restore connection — all 10 deliver in order
- [ ] Kill the app mid-sync — WorkManager resumes on relaunch
- [ ] Duplicate sync request does not create duplicate messages on backend
- [ ] Cold start with queued messages → sync fires automatically
- [ ] `last_sync_timestamp` survives force-stop

---

### Week 5 — QR LAN Fallback (The USP)
**Theme**: Messages delivered with zero internet. Both devices on airplane mode with WiFi only.

**Backend Tasks**
- No backend changes this week — LAN delivery is purely device-to-device
- The cloud sync in Week 4 handles the eventual cloud propagation of LAN-delivered messages

**Flutter Tasks**
- Implement `LanServer`: binds a TCP socket on a random available port, listens for exactly one connection, validates the one-time token, receives and deserialises message JSON, closes after transfer
- Implement `LanClient`: connects to the target IP and port, sends one-time token for validation, serialises and sends pending messages as JSON, awaits acknowledgement
- Implement QR payload generation: `{ ip: device_local_ip, port: server_port, token: uuid_v4, expiry: unix_timestamp + 60 }` — one-use token, 60 second validity
- Get device's local WiFi IP (not `localhost`) — use the `network_info_plus` package
- Implement `QrShareScreen`: displays the generated QR code using `qr_flutter`, shows `loading_animation_widget` while socket server is initialising, shows countdown timer until QR expires, auto-regenerates on expiry
- Implement `QrScanScreen`: uses `mobile_scanner` to scan the QR, parses payload, validates expiry client-side before attempting connection, shows connection status
- Token invalidation: the server closes and the token is discarded immediately after the first successful connection — not reusable
- On successful LAN transfer: update message statuses to `delivered_locally` in Drift, show `toastification` success with message count
- On internet restore: `SyncEngine` picks up `delivered_locally` messages (treating them as unsynced to cloud) and syncs them via `POST /sync`
- Add "Send via local network" button in chat screen — visible only when `ConnectivityService` reports no internet
- Use `font_awesome_flutter` QR code icon for the LAN button

**Week 5 End Checklist**
- [ ] Two phones on same WiFi, airplane mode on both — messages go through
- [ ] QR token cannot be reused — second scan attempt fails cleanly
- [ ] Expired QR (>60s) is rejected by the client before connecting
- [ ] LAN-delivered messages sync to cloud when internet restores
- [ ] `loading_animation_widget` shown while socket is initialising

---

### Week 6 — Lifecycle Hardening & Sync Reconciliation
**Theme**: The app behaves correctly under every lifecycle edge case. Multi-device history stays consistent.

**Backend Tasks**
- Ensure `GET /conversations/{id}/messages` supports pagination (`limit` + `before_timestamp`) — prevents loading thousands of messages on history fetch
- Add `PUT /messages/{id}/status` endpoint for read receipts
- Add `POST /fcm-token` endpoint to update FCM token on the backend when FCM refreshes it

**Flutter Tasks**
- Implement cold start full restoration sequence: restore session from Keystore → restore sync queue from Drift → resume pending WorkManager tasks → reconnect WebSocket → run startup sync
- Test "Don't keep activities" mode (Android Developer Options) — this is the most aggressive lifecycle test
- Deep-link cold start: a notification tap when the app is not running must open the correct conversation without routing to the splash screen first — GoRouter `initialLocation` handles this via the notification payload
- Foreground → background → foreground: WebSocket reconnects, sync catches up — verify with a 5-minute background test
- Low RAM simulation: Android Developer Options → Background process limit: 1 process — verify app restores correctly
- Implement full FCM integration: `FirebaseMessaging.onMessage` (foreground), `onMessageOpenedApp` (background tap), `getInitialMessage` (terminated state tap)
- Show notification when a message arrives and the app is in the background
- Implement FCM token rotation: on `onTokenRefresh`, call `PUT /fcm-token` on the backend
- Implement full notification permission lifecycle: request on first launch, detect permanently denied state, show settings-redirect dialog for permanently denied, handle runtime revocation
- Use `toastification` for in-app notification when a message arrives in foreground

**Week 6 End Checklist**
- [ ] Force-stop → reopen → all state restored, sync resumes
- [ ] Notification tap from terminated state opens correct conversation
- [ ] WebSocket reconnects after 5-minute background period
- [ ] FCM token rotation updates backend correctly
- [ ] Notification permission permanently denied → settings redirect shown

---

### Week 7 — Performance, Local Data at Scale & Diagnostics Screen
**Theme**: Doesn't degrade over time. Migration strategy proven. Cristalyse diagnostics screen built.

**Backend Tasks**
- No major backend changes this week
- Verify `GET /conversations/{id}/messages` pagination works correctly under load
- Add `created_at` indexes on `messages` table if not already present

**Flutter Tasks**

**Schema Migration Test**
- Bump `schemaVersion` to 2 in `AppDatabase`
- Add a new column to the `Messages` table (e.g., `is_starred BOOLEAN DEFAULT false`)
- Add the corresponding `onUpgrade` step: `if (from < 2) await m.addColumn(messages, messages.isStarred)`
- Test: install the app (schema v1 data present), apply the update (schema v2) — data must survive, column added cleanly
- This proves the migration strategy works without data loss

**Memory and Performance**
- Run Flutter DevTools Memory tab with 500+ messages in a conversation — verify no memory leak over 10 minutes of scrolling
- Profile cold start time in DevTools — identify and resolve the single largest startup bottleneck
- Ensure all heavy operations run off the main thread: JSON parsing in a Dart Isolate for large sync payloads, SHA-256 hashing in an Isolate if file transfer is added
- Implement media cache with a 300MB cap and LRU eviction — store only URLs in Drift, never raw bytes
- Test `ListView.builder` recycling — verify `itemBuilder` is not called for off-screen items (use print statements to confirm)

**Cristalyse Diagnostics Screen**
- Add a hidden diagnostics screen accessible via a long-press on the settings icon (or a developer toggle in settings)
- Track sync events in a local `sync_events` Drift table: `{ id, type (websocket/rest/lan), status (success/failure), duration_ms, message_count, timestamp }`
- Line chart (Cristalyse): sync latency over time — x-axis is timestamp, y-axis is `duration_ms`, color by transport type
- Bar chart (Cristalyse): sync outcomes by transport type — grouped bars showing success vs failure counts per type
- Scatter plot (Cristalyse): message delivery timeline — one point per message, x-axis `created_at`, y-axis time-to-delivery in seconds
- All charts use `.interaction(tooltip: TooltipConfig(...))` to show per-point metadata on tap
- Charts animate in using Cristalyse's native 60fps animation engine
- Use `font_awesome_flutter` for section headers in the diagnostics screen (chart icon, activity icon)

**Week 7 End Checklist**
- [ ] Schema migration from v1 to v2 completes without data loss
- [ ] No memory leak detected in DevTools after 10 minutes of use
- [ ] Cold start time measured and documented
- [ ] Cristalyse diagnostics screen shows live sync data
- [ ] Chart tooltips show per-point metadata on tap
- [ ] All chart types animate smoothly (60fps)

---

### Week 8 — Production Hardening & Release
**Theme**: Something you'd actually ship. On the Play Store. Crash-free rate visible.

**Flutter Tasks**

**Biometrics**
- Implement `BiometricService` wrapping `local_auth`
- On app resume from background (after >30 seconds), prompt for biometric authentication
- Handle all `BiometricException` cases: not enrolled, not available, locked out, permanent lockout
- Do not show the biometric prompt if the user has not enrolled — fall back to PIN/pattern
- Use `toastification` warning toast if biometrics are unavailable and app lock is enabled

**Crashlytics**
- Add `firebase_crashlytics` and configure in `main.dart` with `FlutterError.onError` and `PlatformDispatcher.instance.onError`
- Add a deliberate test crash behind a debug button — verify it appears in the Firebase console within 5 minutes
- Add custom keys to crash reports: `user_id`, `sync_status`, `websocket_connected` — these appear in the Crashlytics dashboard and are invaluable for debugging reported crashes
- Log non-fatal errors to Crashlytics: sync failures, WebSocket disconnects, WorkManager task failures

**Analytics Events**
- Track: `sync_completed`, `sync_failed`, `websocket_connected`, `websocket_disconnected`, `lan_delivery_success`, `lan_delivery_failed`, `cold_start_duration`, `message_sent`, `message_delivered`
- These feed the Cristalyse diagnostics screen and the Firebase Analytics dashboard

**Feature Flags**
- Implement a `FeatureFlags` class backed by Firebase Remote Config
- Gate the LAN fallback feature behind `feature_lan_enabled` flag — allows disabling it remotely without a new release
- Gate the diagnostics screen behind `feature_diagnostics_enabled`
- Default values are hardcoded in the app — Remote Config overrides them when available

**Release**
- Build a signed release APK: `flutter build apk --release`
- Create a Play Store internal testing track — upload the APK
- Write a one-page internal testing plan covering: auth flow, offline send, sync-on-reconnect, QR LAN, notification tap from terminated state, biometric lock
- Document known limitations in the README
- Promote from internal → alpha track

**Week 8 End Checklist**
- [ ] Biometric prompt appears on app resume after 30s background
- [ ] Test crash appears in Crashlytics dashboard
- [ ] Custom Crashlytics keys visible in crash reports
- [ ] Feature flags loaded from Remote Config, defaults work offline
- [ ] LAN fallback can be remotely disabled via feature flag
- [ ] Signed APK published to Play Store internal track
- [ ] App promoted to alpha track
- [ ] Crash-free rate visible in Firebase console

### Week 9 — Dual-Routed File Transfer
**Theme**: Send files seamlessly over the internet or LAN, with local-only storage and mid-transfer network handoffs.

**Backend Tasks**
- Implement a temporary chunk-relay or WebRTC signaling endpoint (since files must be stored locally only, the server acts purely as a passthrough or signaling server).
- If using relay, implement `POST /relay/upload` and `GET /relay/download` where chunks are streamed in memory and immediately discarded.

**Flutter Tasks**
- **Dual-Routing**: Implement a `FileTransferService` that dynamically routes file chunks over either `Dio` (internet) or the active TCP `LanConnectionManager` socket.
- **Chunking & Progress**: Split files into 1MB chunks. Track the index of successfully acknowledged chunks to render a real-time progress bar in the UI.
- **Seamless Resume**: If the internet drops mid-transfer, the transfer pauses. When the user connects via LAN, the `FileTransferService` detects the active LAN socket, checks the last acknowledged chunk index, and resumes the transfer from that exact chunk.
- **Local Storage**: Save received chunks directly to the device's local storage (e.g., Application Documents Directory) and store only the local file URI in the Drift database.
- **UI Updates**: Add a file picker button to the message input. Add a `FileMessageBubble` that displays file metadata, the download/upload progress bar, and play/pause/resume controls.

**Week 9 End Checklist**
- [ ] Large file transfers successfully over the internet without being saved to the backend disk.
- [ ] Progress bar updates accurately during transfer.
- [ ] Disconnecting the internet pauses the transfer gracefully.
- [ ] Connecting via QR LAN automatically resumes the file transfer from where it left off.
- [ ] Files are accessible from local device storage after completion.

---

## 11. Folder Structure

### Mono Repo Root
```
pulse/
├── app/                          # FastAPI backend
│   ├── main.py
│   ├── database.py
│   ├── models.py
│   ├── schemas.py
│   ├── security.py
│   ├── dependencies.py
│   └── routers/
│       ├── auth.py
│       ├── messages.py           # Week 3
│       ├── conversations.py      # Week 3
│       └── sync.py               # Week 4
├── migrations/                   # Alembic
│   ├── env.py
│   └── versions/
├── frontend/                     # Flutter app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── injection.dart
│   │   ├── core/
│   │   │   ├── database/
│   │   │   │   ├── app_database.dart
│   │   │   │   ├── app_database.g.dart
│   │   │   │   ├── tables/
│   │   │   │   │   ├── messages.dart
│   │   │   │   │   └── conversations.dart
│   │   │   │   └── daos/
│   │   │   │       ├── message_dao.dart
│   │   │   │       └── conversation_dao.dart
│   │   │   ├── network/
│   │   │   │   ├── api_client.dart
│   │   │   │   └── websocket_manager.dart
│   │   │   ├── storage/
│   │   │   │   └── secure_storage.dart
│   │   │   └── services/
│   │   │       ├── sync_engine.dart
│   │   │       ├── connectivity_service.dart
│   │   │       ├── lan_server.dart
│   │   │       ├── lan_client.dart
│   │   │       ├── biometric_service.dart
│   │   │       └── feature_flags.dart
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   │   ├── data/auth_repository.dart
│   │   │   │   ├── domain/user.dart
│   │   │   │   └── presentation/
│   │   │   │       ├── auth_provider.dart
│   │   │   │       ├── login_screen.dart
│   │   │   │       └── register_screen.dart
│   │   │   ├── chat/
│   │   │   │   ├── data/
│   │   │   │   │   ├── message_repository.dart
│   │   │   │   │   └── conversation_repository.dart
│   │   │   │   ├── domain/
│   │   │   │   │   ├── message.dart
│   │   │   │   │   └── conversation.dart
│   │   │   │   └── presentation/
│   │   │   │       ├── chat_provider.dart
│   │   │   │       ├── conversation_list_screen.dart
│   │   │   │       ├── chat_screen.dart
│   │   │   │       └── widgets/
│   │   │   │           ├── message_bubble.dart
│   │   │   │           └── message_input.dart
│   │   │   ├── lan/
│   │   │   │   └── presentation/
│   │   │   │       ├── qr_share_screen.dart
│   │   │   │       └── qr_scan_screen.dart
│   │   │   ├── diagnostics/
│   │   │   │   └── presentation/
│   │   │   │       └── diagnostics_screen.dart
│   │   │   └── settings/
│   │   │       └── presentation/
│   │   │           └── settings_screen.dart
│   │   └── routing/
│   │       └── app_router.dart
│   ├── pubspec.yaml
│   └── android/
├── docker-compose.yml
├── Dockerfile
├── requirements.txt
├── alembic.ini
├── .env                          # gitignored
├── .gitignore
└── README.md
```

---

## 12. Engineering Depth Checklist

This is what separates Pulse from a standard "I built a chat app" project. Each item should be demonstrable in an interview.

### Offline-First Sync
- [ ] UI reads exclusively from local DB — never from network directly
- [ ] Messages written to DB before any network attempt
- [ ] `getUnsyncedMessages()` is the sync queue — no separate queue data structure
- [ ] `ON CONFLICT DO UPDATE` on backend — idempotent writes
- [ ] `last_sync_timestamp` stored in Keystore — survives kills
- [ ] Delta sync — only changed records transferred, never full re-sync
- [ ] Partial failure handling — sync retries at message granularity, not batch

### Lifecycle & Process Death
- [ ] WorkManager task survives force-stop and device restart
- [ ] Cold start full restoration sequence documented and tested
- [ ] Deep-link cold start from notification works correctly
- [ ] "Don't keep activities" mode passes all scenarios
- [ ] Background → foreground WebSocket reconnection verified

### Structured Concurrency
- [ ] No `await` chains blocking the UI thread
- [ ] WorkManager used for background work, not Dart Timers
- [ ] Heavy operations (large JSON parse, hashing) run in Dart Isolates
- [ ] `NativeDatabase.createInBackground` used for Drift DB connection

### Local Data at Scale
- [ ] Drift `schemaVersion` + `onUpgrade` tested — data survives migration
- [ ] `ListView.builder` used throughout — no eager rendering
- [ ] Media stored as URLs, not blobs — only metadata in DB
- [ ] Memory profiled — no leak detected after 10 minutes of use

### Performance
- [ ] 60fps confirmed in DevTools with 100+ messages
- [ ] Cold start time measured and documented
- [ ] Draft save is a debounced listener, not a per-keypress write
- [ ] Drift stream subscription disposed correctly on screen dispose

### Platform Integration
- [ ] JWT in Android Keystore via `EncryptedSharedPreferences`
- [ ] FCM token rotation — backend updated when token refreshes
- [ ] All four notification permission states handled
- [ ] Biometric all exception cases handled

### Release Rigour
- [ ] Crashlytics custom keys in all crash reports
- [ ] Feature flags loaded from Remote Config, local defaults present
- [ ] Signed APK on Play Store internal track
- [ ] One-page testing plan written

---

## 13. Resume Positioning

### The One-Line Version
> "Built Pulse — an offline-first Android messaging platform with local-first persistence, idempotent multi-transport sync, QR-based peer-to-peer LAN delivery, and process-death recovery via WorkManager. Shipped to Play Store internal track with staged rollout and Crashlytics monitoring."

### The Interview Answer (when asked to describe a project)
> "I built a chat app where the fundamental design constraint was that it had to work correctly with no internet. Every message is written to a local SQLite database first, the UI updates immediately from that, and a background sync engine handles cloud delivery using idempotent writes — so retries are safe. When there's no internet at all, two devices can exchange messages directly over LAN via a QR handshake. WorkManager ensures sync resumes even if the OS kills the app mid-operation. The backend is FastAPI on Docker with Alembic migrations and OAuth2 auth."

### What to Draw on the Whiteboard
Be ready to draw the message state machine from the "Message Lifecycle" section above. Interviewers who ask about offline-first systems are testing whether you understand the failure modes — not just the happy path.

### Stack-Specific Notes
- FastAPI is uncommon at Indian product companies which often expect Spring Boot — frame it as a deliberate choice for its native async and WebSocket support, not the default
- Drift + Riverpod is a mature, production-grade Flutter stack — not a toy setup
- The Cristalyse diagnostics screen is a differentiator — it shows you understand observability, not just feature delivery