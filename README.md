# Pulse

Pulse is an offline-first Android messaging platform that treats internet connectivity as an optional transport layer. It stores messages locally first via SQLite (Drift) and synchronizes them in the background.

## Current Progress

We have successfully completed **Week 1: Foundation Layer**. 

- **Backend:** Setup is complete with FastAPI, PostgreSQL, SQLAlchemy, and Alembic. The authentication flow (OAuth2 with JWT) is fully implemented (`/auth/register`, `/auth/login`, `/auth/me`).
- **Frontend:** Flutter mono-repo is scaffolded. Drift local database is initialized with initial schemas. GoRouter is configured, and local secure storage with Dio API client setup is complete. The app handles user authentication and persists sessions.

We are currently starting **Week 2: Local-First Chat UI**, focusing on building the offline-capable Drift-driven UI.

## Setup and Startup Instructions

### Backend (FastAPI + PostgreSQL)

The backend is fully dockerized. Ensure you have Docker and Docker Compose installed.

1. Create a `.env` file in the root directory (if not already present).
2. Start the services using Docker Compose:
   ```bash
   docker-compose up -d --build
   ```
3. The API will be available at `http://localhost:8000`. You can explore the interactive API documentation at `http://localhost:8000/docs`.
4. To run Alembic migrations (if you make schema changes), execute them inside the API container:
   ```bash
   docker exec -it pulse_api alembic upgrade head
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
