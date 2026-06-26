import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  await Supabase.initialize(
    url: 'https://lokoxgwymvvnxhmavuyv.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxva294Z3d5bXZ2bnhobWF2dXl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE2MDM3MTEsImV4cCI6MjA5NzE3OTcxMX0.gpQT_54GRBls2q3dpxsKt70tcEkRdDgGVvjocq79qMU',
  );
  
  final client = Supabase.instance.client;
  try {
    final data = await client.from('notifications').select().limit(5);
    print('Notifications rows: $data');
    if (data.isNotEmpty) {
      print('Columns: ${data.first.keys.toList()}');
    }
  } catch (e) {
    print('Error querying notifications: $e');
  }
}
