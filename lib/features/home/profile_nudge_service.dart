import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iconsax/iconsax.dart';

class NudgeItem {
  final String id;
  final String title;
  final String description;
  final String actionRoute;
  final IconData icon;

  NudgeItem({
    required this.id,
    required this.title,
    required this.description,
    required this.actionRoute,
    required this.icon,
  });
}

class ProfileNudgeService {
  static Future<NudgeItem?> getActiveNudge(Map<String, dynamic>? profile, String role) async {
    if (profile == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    Future<bool> isDismissed(String nudgeId) async {
      final key = 'dismissed_nudge_${profile['id']}_$nudgeId';
      final dismissedTimeStr = prefs.getString(key);
      if (dismissedTimeStr == null) return false;
      try {
        final dismissedTime = DateTime.parse(dismissedTimeStr);
        // 7-day cooldown
        if (now.difference(dismissedTime).inDays < 7) {
          return true;
        }
      } catch (_) {}
      return false;
    }

    if (role == 'brand') {
      // 1. Logo
      if (profile['avatar_url'] == null && !await isDismissed('avatar')) {
        return NudgeItem(
          id: 'avatar',
          title: 'Add a brand logo',
          description: 'Mascots or logos build trust with creators.',
          actionRoute: '/brand/profile?edit=true',
          icon: Iconsax.camera,
        );
      }
      // 2. Bio
      final bio = profile['bio'] as String?;
      if ((bio == null || bio.trim().isEmpty) && !await isDismissed('bio')) {
        return NudgeItem(
          id: 'bio',
          title: 'Write a brand description',
          description: 'Briefly describe your company\'s mission.',
          actionRoute: '/brand/profile?edit=true',
          icon: Iconsax.document_text,
        );
      }
      // 3. Website
      final web = profile['website_url'] as String?;
      if ((web == null || web.trim().isEmpty) && !await isDismissed('website')) {
        return NudgeItem(
          id: 'website',
          title: 'Add your website',
          description: 'Link creators directly to your store or home page.',
          actionRoute: '/brand/profile?edit=true',
          icon: Iconsax.global,
        );
      }
      // 4. Budget preferences
      final pref = profile['preferences'] as Map<String, dynamic>? ?? {};
      final budgetRange = pref['target_budget_range'] as String?;
      if ((budgetRange == null || budgetRange.trim().isEmpty) && !await isDismissed('budget')) {
        return NudgeItem(
          id: 'budget',
          title: 'Set campaign targets',
          description: 'Provide target budgets and audience details.',
          actionRoute: '/brand/profile?edit=true',
          icon: Iconsax.briefcase,
        );
      }
    } else {
      // Creator
      // 1. Photo
      if (profile['avatar_url'] == null && !await isDismissed('avatar')) {
        return NudgeItem(
          id: 'avatar',
          title: 'Add a profile photo',
          description: 'Profiles with photos get 3x more interest from brands.',
          actionRoute: '/influencer/profile?edit=true',
          icon: Iconsax.camera,
        );
      }
      // 2. Bio
      final bio = profile['bio'] as String?;
      if ((bio == null || bio.trim().isEmpty) && !await isDismissed('bio')) {
        return NudgeItem(
          id: 'bio',
          title: 'Write a short bio',
          description: 'Tell brands about your content style and audience.',
          actionRoute: '/influencer/profile?edit=true',
          icon: Iconsax.document_text,
        );
      }
      // 3. Niches
      final niches = profile['niche'] as List?;
      if ((niches == null || niches.isEmpty) && !await isDismissed('niches')) {
        return NudgeItem(
          id: 'niches',
          title: 'Select your niches',
          description: 'Niches help brands discover you in search.',
          actionRoute: '/influencer/profile?edit=true',
          icon: Iconsax.category,
        );
      }
      // 4. Location
      final location = profile['location'] as String?;
      if ((location == null || location.trim().isEmpty) && !await isDismissed('location')) {
        return NudgeItem(
          id: 'location',
          title: 'Set your location',
          description: 'Let brands know where you are located.',
          actionRoute: '/influencer/profile?edit=true',
          icon: Iconsax.location,
        );
      }
      // 5. Social platforms
      final platforms = profile['platforms'] as List?;
      if ((platforms == null || platforms.isEmpty) && !await isDismissed('platforms')) {
        return NudgeItem(
          id: 'platforms',
          title: 'Connect social accounts',
          description: 'Connect at least one platform to show your reach.',
          actionRoute: '/influencer/profile?edit=true',
          icon: Iconsax.link,
        );
      }
    }
    return null;
  }

  static Future<void> dismissNudge(String userId, String nudgeId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'dismissed_nudge_${userId}_$nudgeId';
    await prefs.setString(key, DateTime.now().toIso8601String());
  }
}
