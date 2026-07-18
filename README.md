# Pulse

Pulse is an offline-first Android messaging platform that treats internet connectivity as an optional transport layer. It stores messages locally first via SQLite (Drift) and synchronizes them in the background.

## Current Progress

We have successfully completed **Week 1 (Foundation)**, **Week 2 (Local-First Chat UI)**, and **Week 3 (WebSocket Real-Time Delivery)**. We have also started implementing foundational aspects of **Week 4 (Offline Sync Engine)**.

### Implemented Features:
- **Backend & Auth:** FastAPI, PostgreSQL, SQLAlchemy, Alembic. OAuth2 JWT authentication (`/auth/register`, `/auth/login`, `/auth/me`).
- **Offline-First UI:** Flutter UI fully driven by local SQLite (Drift) streams. Messages appear instantly upon sending without waiting for network.
- **Draft Persistence:** Unsent message drafts are saved to encrypted secure storage natively and persist across app kills.
- **Connection Management:** Conversation Requests flow (`/requests`) allowing users to request chats by username, and accept/reject pending requests.
- **Real-Time Delivery:** WebSocket implementation allowing instant bidirectional message exchange and active typing indicators.
- **Message Status Ticks:** 
  - 🕒 **Pending:** Saved locally, not yet synced.
  - ✓ **Sent:** Received by the server.
  - ✓✓ **Delivered:** Received by the recipient.
- **Clock-Skew Resilient Delta Sync:** Background REST sync (`/messages/sync`) using server-generated high-water marks (`synced_at`) stored in Android Keystore to guarantee no messages are lost during cold starts, regardless of device clock drift.

## Setup and Startup Instructions

### Backend (FastAPI + PostgreSQL)

The backend is fully dockerized. Ensure you have Docker and Docker Compose installed.

1. Create a `.env` file in the root directory (if not already present).
2. Start the services using Docker Compose:
   ```bash
   docker compose up -d --build
   ```
3. The API will be available at `http://localhost:8000`. You can explore the interactive API documentation at `http://localhost:8000/docs`.
4. To run Alembic migrations (if you make schema changes), execute them inside the API container:
   ```bash
   docker compose exec api alembic upgrade head
   ```

### Frontend (Flutter)

1. Ensure you have the Flutter SDK installed and an emulator running (or physical Android device connected).
2. Navigate to the `frontend` directory:
   ```bash
   cd frontend
   ```
3. Fetch dependencies:
   ```bash
   flutter pub get
   ```
4. Run code generation (required for Drift and other packages):
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
5. Run the app:
   ```bash
   flutter run
   ```
