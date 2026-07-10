# 📂 Workspace Directory Layout & Responsibilities

This file explains the purpose of each directory in the **Promo** repository to help developers navigate the codebase easily.

## 1. Flutter Mobile App Folder (`/lib`)
- `lib/main.dart`: App entry point. Handles url strategies, initializes Supabase and Firebase, and wraps the application in the Riverpod `UncontrolledProviderScope`.
- `lib/app.dart`: High-level widget configuring Sentry navigation observers, theme provider watches, dynamic maintenance/force-update locks, and security gates.
- `lib/core/`: Common tools.
  - `core/config/`: App environment parameters.
  - `core/deeplink/`: Redirect handler maps.
  - `core/lifecycle/`: Observes app transitions (e.g. validating auth on resume).
  - `core/network/`: Connectivity checkers.
  - `core/providers/`: Global state providers (Authentication, Router, Theme).
  - `core/router/`: App routes, navigation keys, and transitions.
  - `core/security/`: TOTP calculators, biometric readers, session guards, and resume gates.
  - `core/services/`: Core logic (realtime chat, agreements, storage, blocks, notification queues).
  - `core/theme/`: Custom typography and adaptive themes.
- `lib/features/`: Module groupings (e.g. `auth/`, `brand/`, `chat/`, `settings/`, `admin/`, `agreements/`, `trust/`, `support/`).
- `lib/shared/`: Widgets shared across multiple screens (e.g. offline alerts, password strength meters, image croppers, privacy guards).

## 2. Supabase Backend Folder (`/supabase`)
- `supabase/functions/`: Deno-based edge handlers (`mcp-gateway`, `og-preview`, `send-push-notification`, `send-reply`).
- `supabase/migrations/`: SQL migration files defining database updates, tables, policies, functions, triggers, and migrations.

## 3. Web Landing Page Folder (`/promo_landingpage`)
- `promo_landingpage/src/app/`: Next.js pages containing terms/privacy docs, public link-in-bio screens (`/@username`), and core SEO structures.
- `promo_landingpage/src/lib/`: Web-specific tools (logger, twilio verification, whatsapp relays, analytics).