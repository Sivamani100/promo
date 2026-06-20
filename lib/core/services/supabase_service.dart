import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://lokoxgwymvvnxhmavuyv.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxva294Z3d5bXZ2bnhobWF2dXl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE2MDM3MTEsImV4cCI6MjA5NzE3OTcxMX0.gpQT_54GRBls2q3dpxsKt70tcEkRdDgGVvjocq79qMU';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    );
  }
}