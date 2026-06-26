import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../utils/input_sanitizer.dart';

class DisputeService {
  final SupabaseClient _client = SupabaseService.client;

  Map<String, dynamic> _sanitizeDisputeData(Map<String, dynamic> data) {
    final sanitized = Map<String, dynamic>.from(data);
    if (sanitized.containsKey('description') && sanitized['description'] is String) {
      sanitized['description'] = InputSanitizer.sanitizeText(sanitized['description'] as String);
    }
    return sanitized;
  }

  Future<Map<String, dynamic>?> getDispute(String id) async {
    final data = await _client
        .from('disputes')
        .select('*, agreement:collaboration_agreements(*), raiser:profiles!raised_by_fkey(*), opponent:profiles!against_fkey(*)')
        .eq('id', id)
        .maybeSingle();
    return data;
  }

  Future<List<Map<String, dynamic>>> getDisputesForAgreement(String agreementId) async {
    final data = await _client
        .from('disputes')
        .select('*')
        .eq('agreement_id', agreementId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> getDisputesRaisedByMe(String userId) async {
    final data = await _client
        .from('disputes')
        .select('*, opponent:profiles!against_fkey(*)')
        .eq('raised_by', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> getDisputesAgainstMe(String userId) async {
    final data = await _client
        .from('disputes')
        .select('*, raiser:profiles!raised_by_fkey(*)')
        .eq('against', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> raiseDispute({
    required String agreementId,
    String? paymentId,
    required String raisedBy,
    required String against,
    required String category,
    required String description,
    List<String>? evidenceUrls,
  }) async {
    final data = {
      'agreement_id': agreementId,
      'payment_id': paymentId,
      'raised_by': raisedBy,
      'against': against,
      'category': category,
      'description': description,
      'evidence_urls': evidenceUrls ?? [],
      'status': 'open',
    };

    final sanitized = _sanitizeDisputeData(data);
    final response = await _client
        .from('disputes')
        .insert(sanitized)
        .select()
        .single();
    
    // Update agreement status to disputed
    await _client
        .from('collaboration_agreements')
        .update({'status': 'disputed'})
        .eq('id', agreementId);
    
    if (paymentId != null) {
      await _client
          .from('payment_records')
          .update({'status': 'disputed'})
          .eq('id', paymentId);
    }

    return response;
  }

  Future<void> resolveDisputeByAdmin(
    String id, {
    required String resolution,
    required String status, // 'resolved' or 'escalated'
  }) async {
    final updates = {
      'status': status,
      'resolution': resolution,
      'resolved_at': DateTime.now().toIso8601String(),
    };
    await _client.from('disputes').update(updates).eq('id', id);

    // Also update agreement/payment status back to active/completed depending on resolution
    final dispute = await _client
        .from('disputes')
        .select('agreement_id, payment_id')
        .eq('id', id)
        .single();
    
    final agreementId = dispute['agreement_id'] as String?;
    final paymentId = dispute['payment_id'] as String?;
    
    if (status == 'resolved') {
      if (agreementId != null) {
        await _client
            .from('collaboration_agreements')
            .update({'status': 'completed'}) // or negotiating/both_accepted
            .eq('id', agreementId);
      }
      if (paymentId != null) {
        await _client
            .from('payment_records')
            .update({'status': 'completed'})
            .eq('id', paymentId);
      }
    }
  }
}
