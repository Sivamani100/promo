import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class OnboardingAnalyticsService {
  static final SupabaseClient _client = SupabaseService.client;

  static Future<void> logEvent({
    required String userId,
    required int stepNumber,
    required String stepName,
    required String eventType, // 'started', 'completed', 'skipped', 'abandoned'
    int? timeSpentSeconds,
    String? errorEncountered,
  }) async {
    try {
      await _client.from('onboarding_events').insert({
        'user_id': userId,
        'step_number': stepNumber,
        'step_name': stepName,
        'event_type': eventType,
        if (timeSpentSeconds != null) 'time_spent_seconds': timeSpentSeconds,
        if (errorEncountered != null) 'error_encountered': errorEncountered,
      });
      print('[ONBOARDING_ANALYTICS] Logged step $stepNumber ($stepName) $eventType');
    } catch (e) {
      print('[ONBOARDING_ANALYTICS] Failed to log onboarding event: $e');
    }
  }
}
