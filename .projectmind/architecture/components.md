# 🧩 UI Shared Components Handbook

The `/lib/shared/widgets/` directory contains global reusable widgets designed to maintain UI consistency.

## 1. `AppScaffold`
- An adaptive layout controller that renders the matching navigation bar (Brand, Influencer, Admin) and standard app bars.

## 2. `OfflineBanner`
- Uses `connectivity_plus` to listen to network status changes. It renders a subtle animated banner at the top of the screen when offline, blocking connection-required actions.

## 3. `AppPrivacyGuard`
- Listens to app lifecycle states. When the app is backgrounded, it overlays a secure screen to protect sensitive data from appearing in the recent apps previews.

## 4. `PasswordStrengthMeter`
- An interactive indicator that evaluates password strength dynamically using checks for length, uppercase letters, numbers, and special characters.