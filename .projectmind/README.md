# 🧠 ProjectMind: Unified AI Memory & Developer Handbook

Welcome to the **ProjectMind** directory for the **Promo** platform. This hidden directory serves as the single source of truth for both developers and agentic coding models (like Antigravity) to onboard, query, and synchronize memory with the current state of the repository.

Instead of scanning thousands of lines of Dart, TypeScript, or SQL, any AI session or developer can read the files within this directory to understand:
- The overall clean, feature-first codebase architecture.
- Core database entities, schema, relations, and row-level security (RLS) policies.
- Endpoint specs, response types, and edge function triggers.
- Feature workflows, screens, widgets, and state management providers.

---

## 📂 Directory Layout
```text
.projectmind/
├── README.md                <-- You are here (Introduction to memory)
├── project.json             <-- Project tech specifications & metadata
├── current_state.json       <-- Tracking active sprint, task, and sessions
├── project_summary.md       <-- Detailed one-page system overview
├── rules.md                 <-- Code quality, security, and styling handbook
├── roadmap.md               <-- Timeline of completed & upcoming features
│
├── architecture/            <-- System layers, folders, state, and routes
├── features/                <-- Deep specifications for each of the 15 features
├── backend/                 <-- Serverless controller/worker configurations
├── database/                <-- Table schemas, RLS rules, indices, and functions
├── auth/                    <-- JWT, session persistence, and TOTP 2FA setup
├── api/                     <-- REST, realtime channels, and endpoint models
├── env/                     <-- Environment variables mapping and safe tracking
├── ui/                      <-- Screen-to-widget indices, themes, and animations
├── codebase/                <-- Class indexing, functions, and import registries
├── dependencies/            <-- Package logs (pubspec, npm, Cocoapods)
├── workflows/               <-- Visual user paths (Escrow, login, checkout)
├── tasks/                   <-- Current TODO, Doing, Review, and Done logs
├── sessions/                <-- Historic AI conversation summary journals
├── changelog/               <-- Structured development change histories
└── decisions/               <-- Architectural Decision Records (ADRs)
```

## 🔄 How to Synchronize ProjectMind
ProjectMind must be updated automatically:
1. **AI Session Start**: Read `current_state.json`, `project_summary.md`, and `rules.md` to load the context.
2. **Coding Task Execution**: Compare the git diff to identify files modified.
3. **AI Session Complete**: Automatically update the corresponding metadata files (e.g., if a new table or screen was created, update `/database/tables.json` or `/ui/screens.json`), write a session summary under `/sessions/`, and update `current_state.json`.

---
*Created by Antigravity ProjectMind Manager.*