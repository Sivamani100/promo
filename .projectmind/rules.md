# 🛡️ Code Quality & Hardening Guidelines

This handbook defines the strict rules that all developers and AI agents must follow when modifying the **Promo** codebase. These rules are designed to ensure safety, robustness, clean separation of concerns, and security.

---

## 1. State Management (Riverpod)
- **Global Context**: Never read providers globally without a `WidgetRef` or `ProviderContainer`.
- **Logic Separation**: Screens (`View` layers) must contain zero business logic. All interactions should be dispatched to notifier controllers.
- **Auto-Dispose**: Always suffix providers with `.autoDispose` unless they represent long-lived connections (like authentication state or web socket channels).

## 2. Navigation & Gates (GoRouter)
- **Gate Enforcement**: All app-wide constraints (Terms of Service agreement, privacy consents, 2FA validation, banned account states) must be resolved in the central `redirect` callback of `app_router.dart`.
- **Parameter Validation**: Path and query parameters must be validated and sanitized before passing them to detail screens.

## 3. Database Integrity & Supabase RLS
- **RLS Policy**: Row-Level Security must be enabled on every table. Every policy must contain explicit checks (e.g. comparing `auth.uid()` against profile IDs).
- **ACID Operations**: Complex data mutations involving multiple tables (e.g. creating a group room and adding default members, or canceling an agreement and refunding payments) must be wrapped in PostgreSQL Transactions or executed via database RPCs.

## 4. Input Sanitization & Security Hardening
- **Path Traversal**: File uploads must use secure, generated UUID names in paths scoped to the user ID (e.g. `avatars/userId/uuid.png`) to prevent folder traversal exploits.
- **Magic Bytes Validation**: File uploads must verify magic bytes signatures (JPEG, PNG, WebP, PDF) to prevent executing uploaded shell scripts or renaming files to bypass extension blocks.
- **Input Sanitization**: All chat messages, titles, and descriptions must be stripped of HTML tags, script segments, or SQL triggers before insertion.

## 5. Environment Variables & Secrets
- **Zero Raw Secrets**: Under no circumstances should API keys, database credentials, or Sentry keys be hardcoded in the codebase.
- **Dynamic Configuration**: Variables must be fetched dynamically using `String.fromEnvironment()` (Flutter) or `process.env` (Next.js/Deno).