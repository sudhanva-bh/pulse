# Pulse

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev/) 
[![FastAPI](https://img.shields.io/badge/FastAPI-005571?style=for-the-badge&logo=fastapi)](https://fastapi.tiangolo.com/)
[![Postgres](https://img.shields.io/badge/postgres-%23316192.svg?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org/)

Pulse is a highly resilient offline-first messaging platform engineered to treat internet connectivity as an optional transport layer. By seamlessly blending real-time Cloud WebSocket communication with a fallback Local Area Network (LAN) Peer-to-Peer TCP architecture, Pulse guarantees that your conversations and heavy file transfers never stop, even when the internet goes down. Built with Flutter and FastAPI, Pulse provides robust messaging across distributed and unstable networks.

## Key Features

### 1. Dual-Topology Networking
* **Cloud Mode:** Features real-time bidirectional WebSocket communication backed by a scalable FastAPI and PostgreSQL server infrastructure.
* **LAN Fallback (P2P):** When the internet connection drops, users can scan a secure QR code to instantly initialize a persistent, authenticated raw TCP socket over the local network. Messages bypass the cloud entirely and are delivered directly device to device.
* **Auto-Handoff:** The networking engine seamlessly transitions between LAN and Cloud networks. Once the internet is restored, Pulse automatically drops the local socket and hands the active session back to the cloud server.

### 2. Ephemeral Dual-Routed File Transfers
* Users can send large files (500MB and above) instantly.
* **Memory Relay:** On the cloud network, the FastAPI backend acts as an ephemeral chunk relay using asynchronous memory queues. Files are streamed directly to the recipient without ever touching the server disk space, ensuring complete privacy and minimizing server overhead.
* **Pause and Resume:** File chunking state is meticulously preserved. If your internet connection dies in the middle of a transfer, you can scan the LAN QR code to establish a local connection, and the transfer will seamlessly resume streaming exactly where it left off.

### 3. True Offline-First Architecture
* The Flutter user interface is fully reactive and driven exclusively by streams from a local SQLite (Drift) database.
* When you send a message, the content appears instantly on your screen. Background synchronization engines utilizing high-water marks handle the eventual consistency and deliver the payload once a valid transport method (Cloud or LAN) is available.
* The application provides complete message status tracking with detailed indicators for states such as Pending, Sent, Delivered, and Delivered Locally.

## Tech Stack

### Frontend (Mobile App)
* **Framework:** Flutter and Dart
* **State Management:** Riverpod 2.0 with code generation
* **Local Database:** Drift (SQLite) featuring background schema migrations
* **Networking:** Dio for REST endpoints, WebSocketChannel for cloud streams, and Raw dart:io Sockets for local peer to peer communication
* **Other Utilities:** QR code generation and scanning (qr_flutter, mobile_scanner), open_filex for native file viewing on the device.

### Backend (Relay Server)
* **Framework:** FastAPI (Python 3)
* **Database:** PostgreSQL via SQLAlchemy and Alembic for schema migrations
* **Authentication:** Secure OAuth2 JSON Web Token bearer authentication.
* **Architecture:** Stateless WebSocket connection handlers coupled with ephemeral asyncio.Queue objects for memory-based file chunk routing.

## Setup and Startup Instructions

### Backend Configuration

The backend environment is fully dockerized. Ensure you have Docker and Docker Compose installed on your system.

1. Start the FastAPI and Postgres services using Docker Compose:
   ```bash
   docker-compose up -d --build
   ```
2. The Application Programming Interface runs at `http://localhost:8000`. You can explore the interactive API documentation at `http://localhost:8000/docs`.
3. Apply database migrations to configure the PostgreSQL schema correctly:
   ```bash
   docker-compose exec api alembic upgrade head
   ```
4. View the real-time server logs:
   ```bash
   docker-compose logs -f api
   ```
5. Shut down the backend containers gracefully:
   ```bash
   docker-compose down
   ```

### Frontend Configuration

1. Ensure you have the Flutter SDK installed.
2. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```
3. Fetch the required Dart dependencies:
   ```bash
   flutter pub get
   ```
4. Run the code generation step for Drift and Riverpod state management:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
5. Modify the WebSocket and API URLs in `api_client.dart` and `websocket_manager.dart` if you are running the application on a physical device instead of a local Android emulator.
6. Launch the application:
   ```bash
   flutter run
   ```

## Security and Privacy

* Messages routed via the Local Area Network are protected against spoofing through a secure Token-based QR authentication handshake before the TCP stream is successfully opened.
* The backend application acts strictly as an ephemeral relay. All file payloads are stored exclusively on the internal sandboxes of the communicating devices and are never written to a centralized disk.
