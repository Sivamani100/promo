# SignUp Workflow
1. User provides Email, Password, Display Name, and Role ('brand' or 'influencer').
2. Supabase auth user is created, triggering profile creation.
3. User must accept Terms of Service (`/terms-gate`) and select privacy preferences (`/consent`).
4. User completes Onboarding pages to fill out bio/details.
5. User is routed to Dashboard.
