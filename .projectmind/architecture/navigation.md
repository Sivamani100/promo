# 🧭 GoRouter Navigation & Transition Gates

Navigation is managed via **GoRouter** to enable strict, declarative path handling and compile-time role redirections.

## 1. Route Redirection Gates
The router uses a `redirect` callback that acts as an interceptor. It checks the following states in order:
1. **Splash Gate**: If splash loading is incomplete, hold user on `/splash`.
2. **Auth State Gate**: If not logged in, redirect to `/login` (unless accessing public leaderboard or link-in-bio pages).
3. **2-Factor Authentication (2FA) Gate**: If the user has TOTP enabled but has not verified, redirect to `/verify-2fa`.
4. **Suspension/Ban Gate**: If the user's `account_status` is `suspended` or `banned`, force redirection to `/suspended` or `/banned`.
5. **Terms & Consent Gate**: Check if the user has accepted the latest Terms of Service (`tos_version_accepted == '1.0'`) and completed privacy consent flags. If not, redirect to `/terms-gate` or `/consent`.
6. **Onboarding Gate**: If onboarding is incomplete, redirect to `/onboarding/1`.

## 2. ShellRoutes (Adaptive Navigation Scaffolds)
- **Brand ShellRoute**: Wraps home, cards, applications, saved-lists, chats, analytics, and profile screens with a Brand-tailored adaptive bottom bar.
- **Influencer ShellRoute**: Wraps home, discover campaigns, applications, milestone logs, portfolio, chats, analytics, and profile screens.
- **Admin ShellRoute**: Provides quick access to user reports, verification queues, audit logs, and account deletions.

## 3. Route Transitions
- **Slide Left**: Used for default screen navigation (e.g. detail screens).
- **Slide Up Modal**: Used for creation forms (e.g. creating a campaign card) or image viewer slides.
- **Fade**: Used for bottom bar navigation screens to provide smooth layout switches.