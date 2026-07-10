# Login Workflow
1. User enters Email and Password or clicks Google Sign-In.
2. If credentials match, check if user profile has `totp_enabled`.
3. If TOTP 2FA enabled, redirect to `/verify-2fa` for auth check.
4. If not completed onboarding, send to `/onboarding/1`.
5. Else, route to role dashboard (`/brand/home` or `/influencer/home`).
