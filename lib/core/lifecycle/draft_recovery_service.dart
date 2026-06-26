import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Auto-saves and recovers card creation wizard drafts.
///
/// When a user partially fills the card creation wizard and the app
/// is backgrounded or killed, the draft is preserved in SharedPreferences.
/// On wizard re-open, offers to resume from the saved draft.
class DraftRecoveryService {
  DraftRecoveryService._();

  static const String _draftPrefix = 'card_draft_';

  /// Save the current wizard state as a draft.
  static Future<void> saveDraft({
    required String userId,
    required Map<String, dynamic> formData,
    required int currentStep,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final draft = {
      'form_data': formData,
      'current_step': currentStep,
      'saved_at': DateTime.now().toIso8601String(),
    };
    await prefs.setString('$_draftPrefix$userId', jsonEncode(draft));
    debugPrint('[DRAFT] Saved draft for user $userId at step $currentStep');
  }

  /// Check if a draft exists for the given user.
  static Future<DraftData?> getDraft(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('$_draftPrefix$userId');
    if (json == null) return null;

    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return DraftData(
        formData: data['form_data'] as Map<String, dynamic>,
        currentStep: data['current_step'] as int,
        savedAt: DateTime.parse(data['saved_at'] as String),
      );
    } catch (e) {
      debugPrint('[DRAFT] Failed to parse draft: $e');
      await clearDraft(userId);
      return null;
    }
  }

  /// Clear the draft after successful publish or explicit discard.
  static Future<void> clearDraft(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_draftPrefix$userId');
    debugPrint('[DRAFT] Cleared draft for user $userId');
  }

  /// Check if a draft exists (without loading it).
  static Future<bool> hasDraft(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('$_draftPrefix$userId');
  }
}

/// Parsed draft data returned from [DraftRecoveryService.getDraft].
class DraftData {
  final Map<String, dynamic> formData;
  final int currentStep;
  final DateTime savedAt;

  const DraftData({
    required this.formData,
    required this.currentStep,
    required this.savedAt,
  });

  /// Human-readable time since draft was saved.
  String get timeAgo {
    final diff = DateTime.now().difference(savedAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }
}
