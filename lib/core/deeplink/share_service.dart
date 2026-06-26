import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Service for generating shareable links and share images for Promo entities.
///
/// Supports sharing cards, profiles, and referral links with rich message
/// templates and optional share card images for social media.
class ShareService {
  ShareService._();

  static const String _baseUrl = 'https://promo.app';

  // ── Card Sharing ─────────────────────────────────────────────────────────

  /// Share a brand card with a pre-filled message and link.
  static Future<void> shareCard({
    required String cardId,
    required String cardTitle,
    required String brandName,
    String? budget,
  }) async {
    final url = '$_baseUrl/card/$cardId';
    final budgetText = budget != null ? ' — $budget budget' : '';
    final message =
        'Check out this brand collaboration opportunity: $cardTitle by $brandName$budgetText. Apply now: $url';

    await Share.share(message, subject: '$cardTitle — Promo');
  }

  /// Share a card with an invite message for recruiting influencers.
  static Future<void> inviteInfluencersToCard({
    required String cardId,
    required String cardTitle,
    required String brandName,
    String? budget,
  }) async {
    final url = '$_baseUrl/card/$cardId';
    final budgetText = budget != null ? ' ($budget budget)' : '';
    final message =
        '🎯 Looking for creators! $cardTitle by $brandName$budgetText\n\nApply here: $url';

    await Share.share(message, subject: 'Collaboration Opportunity — $cardTitle');
  }

  // ── Profile Sharing ──────────────────────────────────────────────────────

  /// Share an influencer's profile.
  static Future<void> shareInfluencerProfile({
    required String influencerId,
    required String name,
    String? niche,
    String? followerCount,
  }) async {
    final url = '$_baseUrl/influencer/$influencerId';
    final nicheText = niche != null ? ', a $niche creator' : '';
    final followersText =
        followerCount != null ? ' with $followerCount followers' : '';
    final message =
        "I'm $name$nicheText$followersText. Work with me: $url";

    await Share.share(message, subject: '$name — Influencer on Promo');
  }

  /// Share a brand's profile.
  static Future<void> shareBrandProfile({
    required String brandId,
    required String brandName,
  }) async {
    final url = '$_baseUrl/brand/$brandId';
    final message = 'Check out $brandName on Promo: $url';

    await Share.share(message, subject: '$brandName — Promo');
  }

  // ── Referral Sharing ─────────────────────────────────────────────────────

  /// Share a referral invite link.
  static Future<void> shareReferral({required String userId}) async {
    final url = '$_baseUrl/invite?ref=$userId';
    final message =
        '🚀 Join Promo — the platform connecting brands and creators.\n\nSign up here: $url';

    await Share.share(message, subject: 'Join Promo');
  }

  // ── Share Image Generation ───────────────────────────────────────────────

  /// Capture a widget as a PNG image for sharing to WhatsApp, Instagram, etc.
  ///
  /// Pass a [GlobalKey] attached to a [RepaintBoundary] wrapping the widget
  /// you want to capture.
  static Future<Uint8List?> captureWidgetAsImage(GlobalKey key) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('[SHARE] Failed to capture image: $e');
      return null;
    }
  }

  /// Share an image generated from a widget key along with a text message.
  static Future<void> shareWithImage({
    required GlobalKey widgetKey,
    required String message,
    required String subject,
    required String fileName,
  }) async {
    final imageBytes = await captureWidgetAsImage(widgetKey);
    if (imageBytes == null) {
      // Fallback to text-only share
      await Share.share(message, subject: subject);
      return;
    }

    await Share.shareXFiles(
      [
        XFile.fromData(imageBytes, mimeType: 'image/png', name: fileName),
      ],
      text: message,
      subject: subject,
    );
  }
}
