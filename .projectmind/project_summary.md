# 📋 Promo: Connect Brands & Influencers — Core Summary

## 1. System Vision & Purpose
Promo is a modern digital marketplace designed to bridge the gap between Brands seeking advertising and Influencers looking for campaigns. The platform acts as a secure, decentralized workspace where brands create promotional campaigns, influencers apply for assignments, and both coordinate via legally binding milestone agreements with escrow payment protection.

## 2. Core Technical Architecture
The platform is composed of three interconnected parts:
1. **Mobile Application**: Cross-platform client built using Flutter (Dart). It organizes screens in a "Feature-First" format, using **Riverpod** for declarative state caching and **GoRouter** for handling app gates (like Auth, Consent, Two-Factor Authentication, and Account Suspension).
2. **Database & Realtime Backend**: Hosted on **Supabase**. Tables are protected with strict **Row-Level Security (RLS)**. Dynamic operations (e.g. notifications, deep linking metadata, and MCP gateway integration) are handled via Deno-based serverless Edge Functions.
3. **Web Landing & public Bio-Pages**: Built using **Next.js** (TypeScript) to serve public profile pages (`/@username`) with server-side rendering (SSR) for SEO discoverability, as well as tracking page-view analytics.

## 3. Technology Stack & Dependencies
| Component | Technology | Core Dependencies |
|---|---|---|
| **Mobile App** | Flutter / Dart | `flutter_riverpod`, `go_router`, `supabase_flutter`, `flutter_map`, `local_auth` |
| **Backend DB** | PostgreSQL | Row-Level Security, pg_cron, SQL Migrations |
| **Edge Compute** | Deno / TypeScript | Supabase Edge Functions, Twilio / WhatsApp gateways |
| **Web Portal** | Next.js / React | `@supabase/supabase-js`, TailwindCSS (landing styling) |
| **Observability** | Sentry | `sentry_flutter` for crash logs, error reporting, performance monitoring |

## 4. Key Subsystem Integrations
- **Escrow Collaboration Subsystem**: A secure contract manager. Brands and influencers sign agreements mapping payouts to explicit milestones. Payouts are locked in escrow and released on milestone completion, with built-in dispute resolution pipelines.
- **Realtime Chat Subsystem**: Direct and group message chambers. Supporting message editing, deletion (for me / for everyone), stars, pins, reactions, attachments (images, PDFs with type checks), and group members invite policies.
- **Geocoding & Maps**: Interactive maps identifying campaign locations, calculating proximity via `geolocator` and rendering tiles using `flutter_map`.