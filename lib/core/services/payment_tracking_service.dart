import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../utils/input_sanitizer.dart';

class PaymentTrackingService {
  final SupabaseClient _client = SupabaseService.client;

  Map<String, dynamic> _sanitizePaymentData(Map<String, dynamic> data) {
    final sanitized = Map<String, dynamic>.from(data);
    if (sanitized.containsKey('amount') && sanitized['amount'] is String) {
      sanitized['amount'] = InputSanitizer.sanitizeBudget(sanitized['amount'] as String);
    }
    if (sanitized.containsKey('brand_note') && sanitized['brand_note'] is String) {
      sanitized['brand_note'] = InputSanitizer.sanitizeText(sanitized['brand_note'] as String);
    }
    if (sanitized.containsKey('influencer_note') && sanitized['influencer_note'] is String) {
      sanitized['influencer_note'] = InputSanitizer.sanitizeText(sanitized['influencer_note'] as String);
    }
    return sanitized;
  }

  Future<Map<String, dynamic>?> getPaymentRecord(String id) async {
    final data = await _client
        .from('payment_records')
        .select('*, agreement:collaboration_agreements(*)')
        .eq('id', id)
        .maybeSingle();
    return data;
  }

  Future<List<Map<String, dynamic>>> getPaymentsForAgreement(String agreementId) async {
    final data = await _client
        .from('payment_records')
        .select('*')
        .eq('agreement_id', agreementId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> createPaymentRecord({
    required String agreementId,
    required String roomId,
    required String brandId,
    required String influencerId,
    required String amount,
    String currency = 'USD',
  }) async {
    final data = {
      'agreement_id': agreementId,
      'room_id': roomId,
      'brand_id': brandId,
      'influencer_id': influencerId,
      'amount': amount,
      'currency': currency,
      'status': 'pending',
    };

    final sanitized = _sanitizePaymentData(data);
    final response = await _client
        .from('payment_records')
        .insert(sanitized)
        .select()
        .single();
    return response;
  }

  Future<void> markPaymentAsSent(
    String id, {
    required String paymentMethod,
    String? note,
  }) async {
    final data = {
      'status': 'brand_marked_sent',
      'payment_method': paymentMethod,
      'brand_note': note,
      'brand_marked_sent_at': DateTime.now().toIso8601String(),
    };

    final sanitized = _sanitizePaymentData(data);
    await _client.from('payment_records').update(sanitized).eq('id', id);
  }

  Future<void> confirmPaymentReceived(String id, {String? note}) async {
    final data = {
      'status': 'completed',
      'influencer_note': note,
      'influencer_confirmed_at': DateTime.now().toIso8601String(),
    };

    final sanitized = _sanitizePaymentData(data);
    await _client.from('payment_records').update(sanitized).eq('id', id);
    
    // Auto-complete the agreement if all payments are completed
    final record = await _client
        .from('payment_records')
        .select('agreement_id')
        .eq('id', id)
        .single();
    
    final agreementId = record['agreement_id'] as String;
    final allPayments = await getPaymentsForAgreement(agreementId);
    
    final allDone = allPayments.every((p) => p['status'] == 'completed');
    if (allDone) {
      await _client
          .from('collaboration_agreements')
          .update({'status': 'completed'})
          .eq('id', agreementId);
    }
  }

  Future<void> markPaymentDisputed(String id) async {
    await _client.from('payment_records').update({
      'status': 'disputed',
    }).eq('id', id);
  }
}
