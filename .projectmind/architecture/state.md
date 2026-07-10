# ⚡ Riverpod State Management Flow

State management is powered by **Riverpod** (v2) to provide a compile-safe, testable state hierarchy.

## 1. Authentication State Lifecycle
The `authProvider` (implemented via `AuthNotifier`) manages user authentication:
1. **Startup Check**: Looks for a cached session. If found, it parses profile data cached in SharedPreferences.
2. **PKCE Exchange**: On web redirect logins, it exchanges the authorization code for a session token.
3. **Active Listeners**: Subscribes to Supabase auth state changes. When a user logs in, it loads the profile and initializes notifications. When they log out, it deletes token records.

## 2. Configuration State
- `appConfigCheckerProvider`: Periodically watches for changes in `platform_config` to block the application during maintenance periods or force client updates if the version is out-of-date.

## 3. Navigation state
- `routerProvider`: Watches user ID changes in the auth provider to recreate navigator keys, avoiding key reuse assertion exceptions during hot reloads or fast log-outs.