// HARDENING: devops-agent 2026-06-24
class AppConfig {
  static const String env = String.fromEnvironment('ENV', defaultValue: 'dev');
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://lokoxgwymvvnxhmavuyv.supabase.co');
  static const String supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxva294Z3d5bXZ2bnhobWF2dXl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE2MDM3MTEsImV4cCI6MjA5NzE3OTcxMX0.gpQT_54GRBls2q3dpxsKt70tcEkRdDgGVvjocq79qMU');
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');
  
  static const bool isProduction = env == 'prod';
  static const bool showDebugBanner = !isProduction;
  static const int sessionTimeoutDays = isProduction ? 7 : 30;
}
