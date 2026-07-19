import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/supabase_service.dart';
import 'app_snackbar.dart';
import 'shared_widgets.dart';

class FeedbackDialog extends ConsumerStatefulWidget {
  const FeedbackDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const FeedbackDialog(),
    );
  }

  @override
  ConsumerState<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends ConsumerState<FeedbackDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = false;
  bool _success = false;

  // ── NPS ──────────────────────────────────────────────────────────────────
  int _npsScore = 8;
  final _npsCommentCtrl = TextEditingController();

  // ── Bug Report ────────────────────────────────────────────────────────────
  final _bugTitleCtrl   = TextEditingController();
  final _bugDescCtrl    = TextEditingController();
  final _bugStepsCtrl   = TextEditingController();
  final _bugScreenCtrl  = TextEditingController();
  String _bugSeverity   = 'medium';
  // Actual DB: severity IN ('low','medium','high','critical')

  // ── Feature Suggestion ───────────────────────────────────────────────────
  final _ideaTitleCtrl   = TextEditingController();
  final _ideaDescCtrl    = TextEditingController();
  final _ideaProblemCtrl = TextEditingController();
  // DB: category IN ('discovery','chat','profile','cards','analytics','map','onboarding','other')
  String _ideaCategory = 'other';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _npsCommentCtrl.dispose();
    _bugTitleCtrl.dispose();
    _bugDescCtrl.dispose();
    _bugStepsCtrl.dispose();
    _bugScreenCtrl.dispose();
    _ideaTitleCtrl.dispose();
    _ideaDescCtrl.dispose();
    _ideaProblemCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Submit NPS
  // Table: public.feedback  (user_id, type, score, comment, metadata)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _submitFeedback() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      await SupabaseService.client.from('feedback').insert({
        'user_id': user.id,
        'type': 'nps',
        'score': _npsScore,
        'comment': _npsCommentCtrl.text.trim().isEmpty
            ? null
            : _npsCommentCtrl.text.trim(),
        'metadata': {'app_version': '1.0.9'},
      });
      _onSuccess();
    } catch (e) {
      _onError(e);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Submit Bug Report
  // Table: public.bug_reports
  //   title TEXT NOT NULL CHECK (char_length(title) <= 100)
  //   description TEXT NOT NULL CHECK (char_length(description) <= 2000)
  //   steps_to_reproduce TEXT
  //   screen_or_feature TEXT
  //   severity TEXT NOT NULL CHECK (severity IN ('low','medium','high','critical'))
  //   device_type TEXT CHECK (device_type IN ('Android','iOS','Web','Desktop'))
  //   submitter_name TEXT CHECK (char_length <= 60)
  //   submitter_email TEXT NOT NULL (regex validated)
  //   status TEXT DEFAULT 'received'
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _submitBug() async {
    final user    = ref.read(authProvider).user;
    final profile = ref.read(authProvider).profile;
    if (user == null) return;

    final title = _bugTitleCtrl.text.trim();
    final desc  = _bugDescCtrl.text.trim();

    if (title.isEmpty || desc.isEmpty) {
      AppSnackbar.error(context, 'Title and Description are required.');
      return;
    }
    if (title.length > 100) {
      AppSnackbar.error(context, 'Title must be 100 characters or less.');
      return;
    }

    // submitter_email is NOT NULL in DB — use the user's auth email
    final email = user.email ?? '';
    if (email.isEmpty) {
      AppSnackbar.error(context, 'A valid email is required to submit a bug report.');
      return;
    }

    setState(() => _loading = true);
    try {
      await SupabaseService.client.from('bug_reports').insert({
        'title':               title,
        'description':         desc,
        'steps_to_reproduce':  _bugStepsCtrl.text.trim().isEmpty ? null : _bugStepsCtrl.text.trim(),
        'screen_or_feature':   _bugScreenCtrl.text.trim().isEmpty ? null : _bugScreenCtrl.text.trim(),
        'severity':            _bugSeverity,
        'device_type':         'Android',
        'submitter_name':      profile?['display_name']?.toString(),
        'submitter_email':     email,
        'status':              'received',
      });
      _onSuccess();
    } catch (e) {
      _onError(e);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Submit Feature Idea
  // Table: public.idea_submissions
  //   title TEXT NOT NULL CHECK (char_length(title) <= 100)
  //   description TEXT NOT NULL CHECK (char_length(description) <= 3000)
  //   problem_it_solves TEXT
  //   category TEXT NOT NULL CHECK (category IN ('discovery','chat','profile','cards','analytics','map','onboarding','other'))
  //   submitter_name TEXT
  //   submitter_email TEXT NOT NULL (regex validated)
  //   status TEXT DEFAULT 'received'
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _submitIdea() async {
    final user    = ref.read(authProvider).user;
    final profile = ref.read(authProvider).profile;
    if (user == null) return;

    final title = _ideaTitleCtrl.text.trim();
    final desc  = _ideaDescCtrl.text.trim();

    if (title.isEmpty || desc.isEmpty) {
      AppSnackbar.error(context, 'Title and Description are required.');
      return;
    }
    if (title.length > 100) {
      AppSnackbar.error(context, 'Title must be 100 characters or less.');
      return;
    }

    final email = user.email ?? '';
    if (email.isEmpty) {
      AppSnackbar.error(context, 'A valid email is required to submit a feature idea.');
      return;
    }

    setState(() => _loading = true);
    try {
      await SupabaseService.client.from('idea_submissions').insert({
        'title':            title,
        'description':      desc,
        'problem_it_solves': _ideaProblemCtrl.text.trim().isEmpty ? null : _ideaProblemCtrl.text.trim(),
        'category':         _ideaCategory,
        'submitter_name':   profile?['display_name']?.toString(),
        'submitter_email':  email,
      });
      _onSuccess();
    } catch (e) {
      _onError(e);
    }
  }

  void _onSuccess() {
    HapticFeedback.vibrate();
    setState(() {
      _loading = false;
      _success = true;
    });
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        Navigator.pop(context);
        AppSnackbar.show(context, 'Thank you! Your feedback has been logged.');
      }
    });
  }

  void _onError(dynamic error) {
    setState(() => _loading = false);
    final msg = error.toString().contains('violates check constraint')
        ? 'Submission rejected: please check your inputs and try again.'
        : 'Submission failed. Please try again.';
    AppSnackbar.error(context, msg);
    debugPrint('[FEEDBACK_DIALOG] Error: $error');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_success) return _buildSuccessState();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.isDarkMode ? const Color(0xFF16161A) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              _buildTabBar(),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRateTab(),
                    _buildBugTab(),
                    _buildFeatureTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessState() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.isDarkMode ? const Color(0xFF16161A) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Lottie.network(
                'https://lottie.host/db6cf0a2-f3e4-4414-b6a1-cb9e4726e632/H3gVv8Z0Tz.json',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.check_circle_outline, size: 80, color: AppColors.success),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Feedback Received!',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Our team has been notified. Thank you for helping improve Promo.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Feedback & Support',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, color: AppColors.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      indicatorColor: AppColors.purple,
      labelColor: AppColors.purple,
      unselectedLabelColor: AppColors.textMuted,
      labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
      tabs: const [
        Tab(text: 'Rate App'),
        Tab(text: 'Bug'),
        Tab(text: 'Feature'),
      ],
    );
  }

  // ─── NPS Tab ──────────────────────────────────────────────────────────────
  Widget _buildRateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How likely are you to recommend Promo to a friend?',
            style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: List.generate(10, (i) {
                final score = i + 1;
                final isSelected = _npsScore == score;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _npsScore = score);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.purple : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppColors.purple : AppColors.borderSubtle,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$score',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Not likely', style: AppTextStyles.captionSm.copyWith(color: AppColors.textMuted)),
              Text('Very likely', style: AppTextStyles.captionSm.copyWith(color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 20),
          Text('What\'s the main reason for your score?',
              style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _npsCommentCtrl,
            hint: 'Share your suggestions...',
            maxLines: 4,
          ),
          const SizedBox(height: 24),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : AppButton(label: 'Submit Rating', onTap: _submitFeedback),
        ],
      ),
    );
  }

  // ─── Bug Tab ──────────────────────────────────────────────────────────────
  Widget _buildBugTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(
            controller: _bugTitleCtrl,
            label: 'Bug Title *',
            hint: 'e.g. App crashes when sending a photo',
            maxLength: 100,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _bugDescCtrl,
            label: 'What went wrong? *',
            hint: 'Describe what happened...',
            maxLines: 3,
            maxLength: 2000,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _bugStepsCtrl,
            label: 'Steps to Reproduce',
            hint: '1. Go to chat\n2. Tap photo icon...',
            maxLines: 2,
            maxLength: 1000,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _bugScreenCtrl,
            label: 'Screen or Feature',
            hint: 'e.g. Chat Room',
            maxLength: 100,
          ),
          const SizedBox(height: 12),
          Text('Severity', style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['low', 'medium', 'high', 'critical'].map((sev) {
              final isSelected = _bugSeverity == sev;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _bugSeverity = sev);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.purple : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppColors.purple : AppColors.borderSubtle,
                      ),
                    ),
                    child: Text(
                      sev.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : AppButton(label: 'Submit Bug Report', onTap: _submitBug),
        ],
      ),
    );
  }

  // ─── Feature Tab ──────────────────────────────────────────────────────────
  Widget _buildFeatureTab() {
    // DB accepts: 'discovery','chat','profile','cards','analytics','map','onboarding','other'
    final categories = ['discovery', 'chat', 'profile', 'cards', 'analytics', 'map', 'onboarding', 'other'];

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(
            controller: _ideaTitleCtrl,
            label: 'Feature Title *',
            hint: 'e.g. Dark mode for campaign cards',
            maxLength: 100,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _ideaDescCtrl,
            label: 'Describe the Feature *',
            hint: 'What should it do?',
            maxLines: 4,
            maxLength: 3000,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _ideaProblemCtrl,
            label: 'What problem does it solve?',
            hint: 'e.g. Helps brands see changes in influencer metrics...',
            maxLines: 2,
            maxLength: 1000,
          ),
          const SizedBox(height: 12),
          Text('Category', style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories.map((cat) {
              final isSelected = _ideaCategory == cat;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _ideaCategory = cat);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.purple : AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.purple : AppColors.borderSubtle,
                    ),
                  ),
                  child: Text(
                    cat.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : AppButton(label: 'Submit Suggestion', onTap: _submitIdea),
        ],
      ),
    );
  }

  // ─── Helper ───────────────────────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    String? label,
    String? hint,
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      style: TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textMuted),
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
        filled: true,
        fillColor: AppColors.surface2,
        counterStyle: TextStyle(color: AppColors.textMuted, fontSize: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.purple, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
