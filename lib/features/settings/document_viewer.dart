import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';

class DocumentViewerScreen extends StatelessWidget {
  final String title;
  final String docType; // 'tos' | 'privacy'

  const DocumentViewerScreen({
    super.key,
    required this.title,
    required this.docType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: docType == 'tos' ? _buildTos() : _buildPrivacy(),
        ),
      ),
    );
  }

  List<Widget> _buildTos() {
    return [
      Text('Terms of Service', style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text('Last Updated: June 19, 2026', style: AppTextStyles.captionSm),
      const Divider(height: 32),
      _sectionHeader('1. Acceptance of Terms'),
      _bodyText(
        'Welcome to our platform. By accessing or using our mobile application, you agree to comply with and be bound by these Terms of Service. If you do not agree to these terms, please do not use the application.',
      ),
      _sectionHeader('2. Account Registration'),
      _bodyText(
        'To use certain features of the service, you must register for an account. You agree to provide accurate, current, and complete information during registration and to update such information to keep it accurate.',
      ),
      _sectionHeader('3. Collaboration Rules'),
      _bodyText(
        'Influencers and brands must act in good faith when engaging in collaborations. All terms, deliverables, and budgets agreed upon in campaign cards are legally binding between the participating parties.',
      ),
      _sectionHeader('4. Termination of Use'),
      _bodyText(
        'We reserve the right to terminate or suspend your account and access to the services at our sole discretion, without notice, for conduct that we believe violates these Terms of Service or is harmful to other users.',
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _buildPrivacy() {
    return [
      Text('Privacy Policy', style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text('Last Updated: June 19, 2026', style: AppTextStyles.captionSm),
      const Divider(height: 32),
      _sectionHeader('1. Information We Collect'),
      _bodyText(
        'We collect information you provide directly to us when creating an account, editing your profile, connecting social media accounts, or communicating with other users in chat rooms.',
      ),
      _sectionHeader('2. How We Use Information'),
      _bodyText(
        'We use the information we collect to operate, maintain, and improve our services, match creators with brand campaigns, process payments, and send notifications.',
      ),
      _sectionHeader('3. Sharing of Information'),
      _bodyText(
        'Your profile information, connected social handles, and active campaigns are visible to other registered users of the platform. We do not sell or rent your personal information to third parties.',
      ),
      _sectionHeader('4. Data Security'),
      _bodyText(
        'We implement industry-standard security measures to protect your personal data. However, no database or transmission channel is completely secure, and we cannot guarantee absolute security.',
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        text,
        style: AppTextStyles.label.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _bodyText(String text) {
    return Text(
      text,
      style: AppTextStyles.body.copyWith(
        color: AppColors.textSecondary,
        height: 1.5,
      ),
    );
  }
}
