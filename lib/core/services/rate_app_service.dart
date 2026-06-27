import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

/// Service to handle Play Store "Rate the App" prompts.
/// Prompts users who have been active for 7+ days and completed at least 1 collaboration.
class RateAppService {
  static final InAppReview _inAppReview = InAppReview.instance;

  /// Check eligibility and show the rating prompt if eligible.
  static Future<void> checkAndShowRatePrompt(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. Check if they have already rated or declined
      final hasRated = prefs.getBool('has_rated_app') ?? false;
      if (hasRated) return;

      // 2. Check user's first login time (active for 7+ days)
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return;

      final firstOpenStr = prefs.getString('first_open_date_${user.id}');
      if (firstOpenStr == null) {
        // Set first open date today if not set
        await prefs.setString('first_open_date_${user.id}', DateTime.now().toUtc().toIso8601String());
        return;
      }

      final firstOpenDate = DateTime.parse(firstOpenStr);
      final daysDiff = DateTime.now().difference(firstOpenDate).inDays;
      if (daysDiff < 7) {
        return; // Less than 7 days active
      }

      // 3. Check if they have at least 1 completed/active collaboration
      final colData = await SupabaseService.client
          .from('collaboration_agreements')
          .select('id')
          .or('brand_id.eq.${user.id},influencer_id.eq.${user.id}')
          .inFilter('status', ['both_accepted', 'completed'])
          .limit(1);

      if (colData.isEmpty) {
        return; // No collaborations yet
      }

      // 4. Trigger in-app review
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
        await prefs.setBool('has_rated_app', true);
      }
    } catch (e) {
      debugPrint('[RATE_SERVICE] Error checking rating prompt: $e');
    }
  }
}
