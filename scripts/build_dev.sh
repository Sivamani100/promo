#!/bin/bash
# HARDENING: sec-agent 2026-06-24

# Development Environment Build Script
SUPABASE_URL="https://lokoxgwymvvnxhmavuyv.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxva294Z3d5bXZ2bnhobWF2dXl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE2MDM3MTEsImV4cCI6MjA5NzE3OTcxMX0.gpQT_54GRBls2q3dpxsKt70tcEkRdDgGVvjocq79qMU"
FIREBASE_API_KEY="AIzaSyBQfJnq8Jrox4CpgkbBV1W3DBY53fNh1F0"

flutter build apk \
  --dart-define=ENV=dev \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=FIREBASE_API_KEY_WEB="$FIREBASE_API_KEY" \
  --dart-define=FIREBASE_API_KEY_ANDROID="$FIREBASE_API_KEY" \
  --dart-define=FIREBASE_API_KEY_IOS="$FIREBASE_API_KEY" \
  --dart-define=SENTRY_DSN=""
