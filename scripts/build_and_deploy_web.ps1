# DevOps Build & Deployment Automation Script for Vercel (Flutter Web Only)

$SupabaseUrl = "https://lokoxgwymvvnxhmavuyv.supabase.co"
$SupabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxva294Z3d5bXZ2bnhobWF2dXl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE2MDM3MTEsImV4cCI6MjA5NzE3OTcxMX0.gpQT_54GRBls2q3dpxsKt70tcEkRdDgGVvjocq79qMU"
$FirebaseApiKey = "AIzaSyBQfJnq8Jrox4CpgkbBV1W3DBY53fNh1F0"

Write-Host "=== Step 1: Cleaning up unused Landing Page assets ===" -ForegroundColor Cyan
$LandingPageDir = "web/landingpage"
if (Test-Path $LandingPageDir) {
    Write-Host "Removing $LandingPageDir to reduce build size..."
    Remove-Item -Recurse -Force $LandingPageDir
}

Write-Host "`n=== Step 2: Compiling Flutter Web ===" -ForegroundColor Cyan
flutter pub get
flutter build web --release `
  --base-href "/" `
  --no-tree-shake-icons `
  --dart-define=ENV=prod `
  --dart-define=SUPABASE_URL=$SupabaseUrl `
  --dart-define=SUPABASE_ANON_KEY=$SupabaseAnonKey `
  --dart-define=FIREBASE_API_KEY_WEB=$FirebaseApiKey `
  --dart-define=SENTRY_DSN=""

Write-Host "`n=== Step 3: Deploying to Vercel ===" -ForegroundColor Cyan
vercel build --prod --yes
vercel deploy --prebuilt --prod --yes

