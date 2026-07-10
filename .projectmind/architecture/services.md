# 🛠️ Service Layer Specifications

Services act as the core business logic controllers, coordinating API actions, database queries, and input validation.

## 1. `ChatService`
- **Responsibilities**: Creates 1-to-1 or group rooms, manages real-time messaging, reaction emojis, stars, and pins.
- **Security Rule**: Sanitizes all chat input via `InputSanitizer.sanitizeText()` before saving.
- **Realtime Channel**: Sets up websocket feeds filtering changes by room ID.

## 2. `StorageService`
- **Responsibilities**: Handles avatars, portfolio items, and verification documents.
- **Hardening Rules**:
  - Validates file sizes (Max 10MB for avatars, 25MB for others).
  - Validates mime-types (JPEG, PNG, WebP, PDF).
  - Scans magic bytes signatures to prevent extension spoofing.
  - Generates secure, user-scoped UUID file paths to prevent traversal.

## 3. `PushNotificationManager`
- **Responsibilities**: Links user Firebase push tokens with the database.
- **Action Triggers**: Relays alerts through Edge Functions when chat messages are sent or milestone updates occur.