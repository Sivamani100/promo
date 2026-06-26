// HARDENING-V2: trust-agent 2026-06-26
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../utils/input_sanitizer.dart';

/// Service for managing user reports (spam, scam, harassment, etc.)
class ReportService {
  final SupabaseClient _client = SupabaseService.client;

  /// Submit a report against a user, card, or message.
  /// At least one of [reportedId], [reportedCardId], [reportedMessageId] must be provided.
  Future<void> submitReport({
    required String reporterId,
    String? reportedId,
    String? reportedCardId,
    String? reportedMessageId,
    required String reason,
    String? details,
  }) async {
    assert(
      reportedId != null || reportedCardId != null || reportedMessageId != null,
      'At least one reported entity must be specified',
    );

    final data = <String, dynamic>{
      'reporter_id': reporterId,
      'reason': reason,
    };
    if (reportedId != null) data['reported_id'] = reportedId;
    if (reportedCardId != null) data['reported_card_id'] = reportedCardId;
    if (reportedMessageId != null) data['reported_message_id'] = reportedMessageId;
    if (details != null && details.trim().isNotEmpty) {
      data['details'] = InputSanitizer.sanitizeText(details.trim(), maxLength: 500);
    }

    await _client.from('user_reports').insert(data);

    // Check if the reported user has crossed the auto-suspension threshold
    if (reportedId != null) {
      await _checkAutoSuspension(reportedId);
    }
  }

  /// Returns all reports submitted by the current user.
  Future<List<Map<String, dynamic>>> getMyReports(String userId) async {
    final data = await _client
        .from('user_reports')
        .select()
        .eq('reporter_id', userId)
        .order('created_at', ascending: false)
        .timeout(const Duration(seconds: 10));
    return List<Map<String, dynamic>>.from(data);
  }

  /// Checks if a reported user has received too many reports and should be auto-flagged.
  Future<void> _checkAutoSuspension(String reportedId) async {
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
      final result = await _client
          .from('user_reports')
          .select('id')
          .eq('reported_id', reportedId)
          .eq('status', 'pending')
          .gte('created_at', sevenDaysAgo)
          .count(CountOption.exact);

      // Default threshold is 5; could be read from platform_config in the future
      if (result.count >= 5) {
        await _client.from('profiles').update({
          'account_status': 'under_review',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', reportedId);

        // Log the auto-action to audit_logs
        try {
          await _client.from('audit_logs').insert({
            'action': 'auto_flagged_for_review',
            'action_category': 'trust',
            'target_user_id': reportedId,
            'details': 'User flagged for review after receiving ${result.count} pending reports in 7 days.',
          });
        } catch (_) {
          // Audit log failure should not block the main operation
        }
      }
    } catch (e) {
      print('[TRUST] Error checking auto-suspension for $reportedId: $e');
    }
  }

  /// Admin: Get all pending reports
  Future<List<Map<String, dynamic>>> getPendingReports() async {
    final data = await _client
        .from('user_reports')
        .select('*, reporter:profiles!user_reports_reporter_id_fkey(display_name, avatar_url), reported:profiles!user_reports_reported_id_fkey(display_name, avatar_url)')
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .timeout(const Duration(seconds: 15));
    return List<Map<String, dynamic>>.from(data);
  }

  /// Admin: Update report status
  Future<void> updateReportStatus(String reportId, String status, {String? adminNote}) async {
    final data = <String, dynamic>{
      'status': status,
    };
    if (adminNote != null) data['admin_note'] = adminNote;
    if (status == 'reviewed' || status == 'actioned' || status == 'dismissed') {
      data['resolved_at'] = DateTime.now().toIso8601String();
    }
    await _client.from('user_reports').update(data).eq('id', reportId);
  }

  /// Get report count for a specific user (for trust signals)
  Future<int> getReportCountForUser(String userId) async {
    final result = await _client
        .from('user_reports')
        .select('id')
        .eq('reported_id', userId)
        .inFilter('status', ['pending', 'actioned'])
        .count(CountOption.exact);
    return result.count;
  }
}
