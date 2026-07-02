import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/profile_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/app_snackbar.dart';

class CreatorCertificationsScreen extends ConsumerStatefulWidget {
  const CreatorCertificationsScreen({super.key});

  @override
  ConsumerState<CreatorCertificationsScreen> createState() => _CreatorCertificationsScreenState();
}

class _CreatorCertificationsScreenState extends ConsumerState<CreatorCertificationsScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  bool _sharing = false;

  final List<Map<String, dynamic>> _certsList = [
    {
      'id': 'professional_collaborator',
      'title': 'Professional Collaborator',
      'description': 'Demonstrate your understanding of professional brand deals, deadlines, and communication workflows.',
      'icon': Iconsax.award,
      'color': Colors.purple,
      'questionsCount': 10,
      'questions': _collabQuestions,
    },
    {
      'id': 'content_brief_master',
      'title': 'Content Brief Master',
      'description': 'Master the art of reading, interpreting, and executing a campaign brief without missing key requirements.',
      'icon': Iconsax.note_text,
      'color': Colors.blue,
      'questionsCount': 8,
      'questions': _briefQuestions,
    },
    {
      'id': 'rate_negotiation_pro',
      'title': 'Rate Negotiation Pro',
      'description': 'Learn how to professionally price your work, negotiate usage rights, and deal with exclusivity clauses.',
      'icon': Iconsax.money_send,
      'color': Colors.green,
      'questionsCount': 8,
      'questions': _rateQuestions,
    },
  ];

  void _startQuiz(Map<String, dynamic> cert) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizActiveScreen(
          certId: cert['id'],
          certTitle: cert['title'],
          questions: cert['questions'] as List<QuizQuestion>,
          certColor: cert['color'],
        ),
      ),
    );
  }

  void _viewCertificate(Map<String, dynamic> cert, String completionDateStr) {
    final profile = ref.read(authProvider).profile;
    final creatorName = profile?['display_name'] ?? 'Promo Creator';
    
    DateTime completionDate = DateTime.tryParse(completionDateStr) ?? DateTime.now();
    final formattedDate = DateFormat('MMMM d, yyyy').format(completionDate);

    showDialog(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.white,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog.fullscreen(
          backgroundColor: Colors.white,
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Certificate',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
              centerTitle: true,
            ),
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Congrats text at top
                    Text(
                      '🎉 Congratulations!',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'You have earned this certification',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Certificate card
                    RepaintBoundary(
                      key: _repaintKey,
                      child: Container(
                        width: double.infinity,
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final cardSize = constraints.maxWidth;
                              final bottomBarHeight = cardSize * 0.22;
                              final pad = cardSize * 0.055;
                              final avatarSize = cardSize * 0.11;

                              return Container(
                                width: cardSize,
                                height: cardSize,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFAF8F5),
                                  image: DecorationImage(
                                    image: AssetImage('assets/promo_badge.png'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  children: [
                                    // Name & Date overlay on bottom yellow bar
                                    Positioned(
                                      left: 25,
                                      bottom: 15,
                                      height: bottomBarHeight,
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          // Profile Avatar
                                          Container(
                                            width: avatarSize,
                                            height: avatarSize,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 2.0),
                                            ),
                                            child: ClipOval(
                                              child: AppAvatar(
                                                url: profile?['avatar_url'],
                                                fallbackText: creatorName,
                                                size: avatarSize,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: cardSize * 0.03),
                                          // Name and Date
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                creatorName,
                                                style: GoogleFonts.inter(
                                                  fontSize: cardSize * 0.038,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.black,
                                                  letterSpacing: -0.2,
                                                ),
                                              ),
                                              SizedBox(height: cardSize * 0.005),
                                              Text(
                                                'Issued: $formattedDate',
                                                style: GoogleFonts.inter(
                                                  fontSize: cardSize * 0.024,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Share button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _sharing
                            ? null
                            : () async {
                                setDialogState(() => _sharing = true);
                                try {
                                  await _shareCertificate(cert['title']);
                                } finally {
                                  setDialogState(() => _sharing = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.black54,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                          elevation: 0,
                        ),
                        child: _sharing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                'Share to World !',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _shareCertificate(String certTitle) async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      
      // Request frame build completion to capture correctly
      await Future.delayed(const Duration(milliseconds: 300));
      
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      
      final pngBytes = byteData.buffer.asUint8List();

      await Share.shareXFiles(
        [XFile.fromData(pngBytes, name: 'promo_certified_${certTitle.toLowerCase().replaceAll(' ', '_')}.png', mimeType: 'image/png')],
        text: 'I just completed my Promo Certification program and earned my official badge as a Certified $certTitle! 🎓🔥 Check out my Promo profile link to collaborate. #PromoCertified #CreatorEconomy #ProfessionalCollaborator',
      );
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Failed to share certificate: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authProvider).profile;
    final prefs = profile?['preferences'] as Map? ?? {};
    final certs = prefs['certifications'] as Map? ?? {};
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0F) : const Color(0xFFFAF9FB),
      appBar: AppBar(
        title: const Text('Creator Certifications'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Certification Welcome Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E1B4B), const Color(0xFF111827)]
                    : [const Color(0xFFEEF2FF), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? const Color(0xFF312E81) : const Color(0xFFC7D2FE),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5C518),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Iconsax.award, color: Colors.black, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Promo Creator Certifications',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Demonstrate your expertise to brands. Complete these brief situational assessments to earn official verified credentials that display directly on your public Promo profile page and attract higher-paying campaigns.',
                  style: AppTextStyles.body.copyWith(
                    color: isDark ? Colors.white70 : const Color(0xFF374151),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Available Certifications',
            style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          ..._certsList.map((cert) {
            final certKey = cert['id'] as String;
            final isCompleted = certs.containsKey(certKey);
            final completionDateStr = isCompleted ? certs[certKey].toString() : '';
            final certColor = cert['color'] as Color;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141416) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isCompleted
                      ? certColor.withOpacity(0.5)
                      : (isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB)),
                  width: isCompleted ? 1.5 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isCompleted ? certColor.withOpacity(0.12) : (isDark ? Colors.white.withOpacity(0.04) : Colors.grey.withOpacity(0.08)),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isCompleted ? Icons.verified : cert['icon'] as IconData,
                          color: isCompleted ? certColor : (isDark ? Colors.white70 : Colors.grey.shade700),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cert['title'] as String,
                              style: AppTextStyles.label.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              cert['description'] as String,
                              style: AppTextStyles.captionSm.copyWith(
                                color: isDark ? Colors.white60 : Colors.grey.shade600,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.format_list_bulleted_rounded,
                            size: 14,
                            color: isDark ? Colors.white38 : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${cert['questionsCount']} situational scenarios',
                            style: AppTextStyles.captionSm.copyWith(
                              fontSize: 11.5,
                              color: isDark ? Colors.white38 : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      if (isCompleted) ...[
                        ElevatedButton.icon(
                          onPressed: () => _viewCertificate(cert, completionDateStr),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: certColor.withOpacity(0.15),
                            foregroundColor: certColor,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                              side: BorderSide(color: certColor.withOpacity(0.3)),
                            ),
                          ),
                          icon: const Icon(Iconsax.award, size: 16),
                          label: const Text('View Certificate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        ),
                      ] else ...[
                        OutlinedButton(
                          onPressed: () => _startQuiz(cert),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? Colors.white : Colors.black,
                            side: BorderSide(color: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                          child: const Text('Start Quiz', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class QuizQuestion {
  final String questionText;
  final List<String> options;
  final int correctOptionIndex;

  const QuizQuestion({
    required this.questionText,
    required this.options,
    required this.correctOptionIndex,
  });
}

class QuizActiveScreen extends ConsumerStatefulWidget {
  final String certId;
  final String certTitle;
  final List<QuizQuestion> questions;
  final Color certColor;

  const QuizActiveScreen({
    super.key,
    required this.certId,
    required this.certTitle,
    required this.questions,
    required this.certColor,
  });

  @override
  ConsumerState<QuizActiveScreen> createState() => _QuizActiveScreenState();
}

class _QuizActiveScreenState extends ConsumerState<QuizActiveScreen> {
  int _currentIndex = 0;
  int? _selectedAnswerIndex;
  int _correctAnswersCount = 0;
  bool _submitted = false;

  void _submitAnswer() {
    if (_selectedAnswerIndex == null) return;
    
    setState(() {
      _submitted = true;
      if (_selectedAnswerIndex == widget.questions[_currentIndex].correctOptionIndex) {
        _correctAnswersCount++;
      }
    });
  }

  void _nextQuestion() {
    if (_currentIndex < widget.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswerIndex = null;
        _submitted = false;
      });
    } else {
      _showResults();
    }
  }

  void _showResults() async {
    final passingScore = (widget.questions.length * 0.8).ceil(); // 80% passing
    final passed = _correctAnswersCount >= passingScore;

    if (passed) {
      // Save certification in profile preferences
      final authState = ref.read(authProvider);
      final profile = authState.profile;
      if (profile != null) {
        final currentPreferences = profile['preferences'] is Map ? Map<String, dynamic>.from(profile['preferences'] as Map) : <String, dynamic>{};
        final currentCerts = currentPreferences['certifications'] is Map ? Map<String, dynamic>.from(currentPreferences['certifications'] as Map) : <String, dynamic>{};
        
        currentCerts[widget.certId] = DateTime.now().toIso8601String();
        currentPreferences['certifications'] = currentCerts;

        try {
          await ProfileService().updateProfile(profile['id'], {'preferences': currentPreferences});
          ref.read(authProvider.notifier).refreshProfile();
        } catch (e) {
          if (mounted) {
            AppSnackbar.error(context, 'Failed to save certification: $e');
          }
        }
      }
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => QuizResultScreen(
          certTitle: widget.certTitle,
          passed: passed,
          score: _correctAnswersCount,
          totalQuestions: widget.questions.length,
          certColor: widget.certColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentQuestion = widget.questions[_currentIndex];
    final progress = (_currentIndex + 1) / widget.questions.length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0F) : const Color(0xFFFAF9FB),
      appBar: AppBar(
        title: Text('${widget.certTitle} Quiz'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              final confirm = await showPremiumConfirmDialog(
                context: context,
                title: 'Exit Quiz',
                message: 'Are you sure you want to exit? Your progress will be lost.',
                confirmLabel: 'Exit',
                isDestructive: true,
              );
              if (confirm == true && mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Sleek Progress indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Scenario ${_currentIndex + 1} of ${widget.questions.length}',
                      style: AppTextStyles.captionSm.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${((_currentIndex + 1) / widget.questions.length * 100).toInt()}%',
                      style: AppTextStyles.captionSm.copyWith(color: widget.certColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: isDark ? const Color(0xFF1F1F23) : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(widget.certColor),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Question Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141416) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: widget.certColor.withOpacity(0.15),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.certColor.withOpacity(0.04),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Iconsax.info_circle, color: Color(0xFFF5C518), size: 24),
                      const SizedBox(height: 12),
                      Text(
                        currentQuestion.questionText,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Select the most appropriate action:',
                  style: AppTextStyles.label.copyWith(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                // Options list
                ...List.generate(currentQuestion.options.length, (index) {
                  final optionText = currentQuestion.options[index];
                  final isSelected = _selectedAnswerIndex == index;
                  final isCorrectAnswer = index == currentQuestion.correctOptionIndex;

                  Color optionBorderColor = isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB);
                  Color optionBgColor = isDark ? const Color(0xFF141416) : Colors.white;
                  Color optionTextColor = isDark ? Colors.white70 : Colors.black87;

                  if (_submitted) {
                    if (isCorrectAnswer) {
                      optionBorderColor = Colors.green.shade500;
                      optionBgColor = Colors.green.withOpacity(0.08);
                      optionTextColor = Colors.green;
                    } else if (isSelected) {
                      optionBorderColor = Colors.red.shade500;
                      optionBgColor = Colors.red.withOpacity(0.08);
                      optionTextColor = Colors.red;
                    }
                  } else if (isSelected) {
                    optionBorderColor = widget.certColor;
                    optionBgColor = widget.certColor.withOpacity(0.05);
                    optionTextColor = widget.certColor;
                  }

                  return GestureDetector(
                    onTap: _submitted
                        ? null
                        : () => setState(() => _selectedAnswerIndex = index),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        color: optionBgColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: optionBorderColor,
                          width: isSelected || (_submitted && (isCorrectAnswer || isSelected)) ? 2.0 : 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              optionText,
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: optionTextColor,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (_submitted && isCorrectAnswer)
                            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22)
                          else if (_submitted && isSelected)
                            const Icon(Icons.cancel_rounded, color: Colors.red, size: 22)
                          else
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? widget.certColor : (isDark ? Colors.white30 : Colors.grey.shade300),
                                  width: 2,
                                ),
                                color: isSelected ? widget.certColor : Colors.transparent,
                              ),
                              alignment: Alignment.center,
                              child: isSelected
                                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                                  : null,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          // Actions bar
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(20),
              color: isDark ? const Color(0xFF141416) : Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedAnswerIndex == null
                          ? null
                          : (_submitted ? _nextQuestion : _submitAnswer),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.certColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      child: Text(
                        _submitted
                            ? (_currentIndex == widget.questions.length - 1 ? 'Finish Assessment' : 'Next Scenario')
                            : 'Submit Answer',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class QuizResultScreen extends StatelessWidget {
  final String certTitle;
  final bool passed;
  final int score;
  final int totalQuestions;
  final Color certColor;

  const QuizResultScreen({
    super.key,
    required this.certTitle,
    required this.passed,
    required this.score,
    required this.totalQuestions,
    required this.certColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percent = (score / totalQuestions * 100).toInt();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0F) : const Color(0xFFFAF9FB),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Result illustration/Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: passed ? Colors.green.withOpacity(0.12) : Colors.red.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  passed ? Icons.verified_rounded : Iconsax.danger,
                  color: passed ? Colors.green : Colors.red,
                  size: 54,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                passed ? 'Congratulations!' : 'Almost There!',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                passed
                    ? 'You have successfully passed the situational assessment and earned the "$certTitle" verified credential badge!'
                    : 'You got $score out of $totalQuestions correct ($percent%). A passing score of 80% is required. Keep learning and try again!',
                style: AppTextStyles.body.copyWith(
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                  fontSize: 14.5,
                  height: 1.55,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              // Score breakdown card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141416) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Your Score: ',
                      style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
                    ),
                    Text(
                      '$score / $totalQuestions',
                      style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w800,
                        color: passed ? Colors.green : Colors.red,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(width: 1.2, height: 20, color: Colors.grey.shade400),
                    const SizedBox(width: 14),
                    Text(
                      '$percent%',
                      style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w800,
                        color: passed ? Colors.green : Colors.red,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Pop all the way back to certifications page
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: passed ? certColor : Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      child: Text(
                        passed ? 'Back to Certifications' : 'Retry Quiz',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// QUIZ DATA
// -------------------------------------------------------------

const List<QuizQuestion> _collabQuestions = [
  QuizQuestion(
    questionText: 'What is the most professional way to negotiate a campaign deadline extension?',
    options: [
      'Tell the brand on the day of the deadline that you need more time.',
      'Message the brand at least 48 hours in advance, explaining the reason and proposing a new date.',
      'Ignore the messages until you finish the video.',
      'Post the video whenever you want without informing them.'
    ],
    correctOptionIndex: 1,
  ),
  QuizQuestion(
    questionText: 'Which of the following should ALWAYS be done before posting sponsored content?',
    options: [
      'Share it with your friends first.',
      'Send the draft to the brand for review and approval if stated in the brief.',
      'Edit the caption after it is live to add sponsorship disclosures.',
      'Buy bot followers to increase engagement metrics.'
    ],
    correctOptionIndex: 1,
  ),
  QuizQuestion(
    questionText: 'If a brand pays you through the Promo platform, when is payment typically released?',
    options: [
      'Immediately when you sign the agreement.',
      '30 days before the campaign starts.',
      'After the deliverables are submitted, verified, and the campaign timeline is met as per contract.',
      'Only if the video goes viral and gets 100k views.'
    ],
    correctOptionIndex: 2,
  ),
  QuizQuestion(
    questionText: 'Under FTC guidelines, how must you disclose a sponsored post?',
    options: [
      'Put #ad or #sponsored clearly visible in the caption/video, not hidden in a sea of hashtags.',
      'Use a tiny, light-grey font that blends into the background.',
      'Explain it in a comment under the post rather than the caption.',
      'No disclosure is needed if you really like the product.'
    ],
    correctOptionIndex: 0,
  ),
  QuizQuestion(
    questionText: 'What is a "usage right" in influencer marketing?',
    options: [
      'The creator\'s right to use the product in daily life.',
      'The brand\'s license to use the creator\'s content for their own ads/marketing.',
      'The right of followers to share the creator\'s post.',
      'The legal right to get paid in advance.'
    ],
    correctOptionIndex: 1,
  ),
  QuizQuestion(
    questionText: 'What should you do if a product you received for review is defective?',
    options: [
      'Write an angry public post about the brand immediately.',
      'Post the review anyway but lie and say it works perfectly.',
      'Contact the brand representative professionally to explain the issue and request a replacement.',
      'Throw it away and ignore the campaign.'
    ],
    correctOptionIndex: 2,
  ),
  QuizQuestion(
    questionText: 'Why is communication responsiveness important during a campaign?',
    options: [
      'It ensures you get featured on the Promo home screen.',
      'It builds brand trust, resolves details quickly, and leads to repeat collaborations.',
      'It lets you ask for extra payments easily.',
      'Brands do not care about communication responsiveness.'
    ],
    correctOptionIndex: 1,
  ),
  QuizQuestion(
    questionText: 'What does "exclusivity clause" mean in an agreement?',
    options: [
      'The creator can only post content on one social platform.',
      'The creator cannot work with competing brands for a specified period of time.',
      'The creator is the exclusive owner of the brand\'s trademarks.',
      'The post can only be viewed by premium subscribers.'
    ],
    correctOptionIndex: 1,
  ),
  QuizQuestion(
    questionText: 'If a campaign brief requests a "dedicated post", what does that mean?',
    options: [
      'You should dedicate the post to your family.',
      'The post features only the partner brand and their product.',
      'The post mentions 5 different brands in a single video.',
      'The post must stay pinned at the top of your feed forever.'
    ],
    correctOptionIndex: 1,
  ),
  QuizQuestion(
    questionText: 'If a disagreement arises with a brand about deliverables, what is the best course of action?',
    options: [
      'Block the brand\'s team on all platforms.',
      'Delete the content you already posted.',
      'Politely refer to the agreed-upon contract terms, and if unresolved, raise a dispute through Promo support.',
      'Threaten the brand on Instagram stories.'
    ],
    correctOptionIndex: 2,
  ),
];

const List<QuizQuestion> _briefQuestions = [
  QuizQuestion(
    questionText: 'When reading a campaign brief, what are "Deliverables"?',
    options: [
      'The packages shipped to your house.',
      'The specific videos, stories, or posts you are contracted to create and publish.',
      'The statistics of your followers.',
      'The emails you send to the brand.'
    ],
    correctOptionIndex: 1,
  ),
  QuizQuestion(
    questionText: 'If the brief states: "Strictly avoid showing competitor branding in the video," what should you do?',
    options: [
      'Blur the competitor logo poorly.',
      'Show competitor products but talk bad about them.',
      'Ensure no visible logos or products of competing brands are in the frame.',
      'Put a sticker of the partner brand over the competitor logo.'
    ],
    correctOptionIndex: 2,
  ),
  QuizQuestion(
    questionText: 'Why are "Key Messaging Points" included in a brief?',
    options: [
      'They are optional jokes to make the caption funny.',
      'They are the specific product features or benefits the brand wants you to mention.',
      'They are the terms and conditions of the Promo platform.',
      'They are scripts that you must read word-for-word without any personal style.'
    ],
    correctOptionIndex: 1,
  ),
  QuizQuestion(
    questionText: 'If a brief has a deadline of "July 15th for draft submission", when should you post the video on Instagram?',
    options: [
      'July 15th, without showing it to the brand.',
      'Submit the draft to the brand via the app on or before July 15th, and wait for approval before posting.',
      'July 16th, without sending a draft.',
      'Whenever you get the draft approved, even if it is August.'
    ],
    correctOptionIndex: 1,
  ),
  QuizQuestion(
    questionText: 'What does "Call to Action" (CTA) mean in a campaign brief?',
    options: [
      'Calling the brand on the phone.',
      'Asking the brand to take action on your payment.',
      'Prompting the audience to take a specific action, like "Click the link in bio" or "Use code PROMO20".',
      'Liking your own post.'
    ],
    correctOptionIndex: 2,
  ),
  QuizQuestion(
    questionText: 'If the brand\'s brief specifies a vertical 9:16 video ratio, which platform format is this suited for?',
    options: [
      'YouTube Desktop Video.',
      'Instagram Reels / TikTok / YouTube Shorts.',
      'Facebook Landscape Post.',
      'Twitter Header Image.'
    ],
    correctOptionIndex: 1,
  ),
  QuizQuestion(
    questionText: 'What should you do if an instruction in the brief is unclear or contradicts itself?',
    options: [
      'Make a guess and create the content according to your guess.',
      'Message the brand coordinator via the chat room to clarify the instruction.',
      'Complain to support about the poor brief quality.',
      'Skip that instruction and hope the brand doesn\'t notice.'
    ],
    correctOptionIndex: 1,
  ),
  QuizQuestion(
    questionText: 'What is the purpose of "Mandatory Hashtags" in a brief?',
    options: [
      'To make your post look trendy.',
      'They are legally required tags for campaign tracking and brand aggregation.',
      'To hide the fact that the content is sponsored.',
      'There is no purpose; they are optional.'
    ],
    correctOptionIndex: 1,
  ),
];

const List<QuizQuestion> _rateQuestions = [
  QuizQuestion(
    questionText: 'How should you calculate your baseline rate for a sponsored post?',
    options: [
      'Ask for whatever amount you need to buy a new phone.',
      'Base it on your reach, engagement rate, production cost, and historical data.',
      'Charge exactly what your friend charges, regardless of size.',
      'Charge 1 rupee per follower.'
    ],
    correctOptionIndex: 1,
  ),
  QuizQuestion(
    questionText: 'A brand asks you to do a "free product exchange" (gifting) but expects 3 dedicated reels and usage rights. How do you respond?',
    options: [
      'Accept it immediately because free products are always good.',
      'Decline angrily and tell them they are cheap.',
      'Politely explain your production costs and offer a counter-proposal (e.g., 1 story for product, or a paid rate for reels).',
      'Take the product and block the brand.'
    ],
    correctOptionIndex: 2,
  ),
  QuizQuestion(
    questionText: 'A brand wants to purchase "12 months of paid ad usage rights" for your video. How should this affect your pricing?',
    options: [
      'It should be free since the video is already made.',
      'You should charge an additional licensing fee because they are using your likeness to run ads.',
      'It should be cheaper because they are giving you exposure.',
      'You should charge 100 times your base rate.'
    ],
    correctOptionIndex: 1,
  ),
  QuizQuestion(
    questionText: 'What is "exclusivity pricing"?',
    options: [
      'Charging more because you are the only influencer in the campaign.',
      'Charging an extra fee because you cannot work with competing brands during the campaign duration.',
      'Charging less because the brand works exclusively with you.',
      'Charging based on exclusive high-quality cameras.'
    ],
    correctOptionIndex: 1,
  ),
  QuizQuestion(
    questionText: 'What is the benefit of proposing a "package deal" (e.g., 1 video + 2 stories instead of just 1 video)?',
    options: [
      'It allows the brand to get more value and gives you a higher total budget at a slightly discounted per-unit rate.',
      'It requires less work from you.',
      'It guarantees the brand will sign a long-term contract.',
      'It makes the campaign shorter.'
    ],
    correctOptionIndex: 0,
  ),
  QuizQuestion(
    questionText: 'If a brand says: "We don\'t have a budget for this campaign, but we can offer exposure," how should you respond professionally?',
    options: [
      '"Exposure doesn\'t pay my bills, bye!"',
      '"Thank you for the opportunity! As a business, I only take on paid collaborations, but I would love to discuss a custom package that fits your budget."',
      '"I will do it for free if you promise to follow me."',
      'Ignore the message.'
    ],
    correctOptionIndex: 1,
  ),
  QuizQuestion(
    questionText: 'What does "CPM" stand for in pricing discussions?',
    options: [
      'Cost Per Million views.',
      'Cost Per Mille (thousand impressions).',
      'Creator Payment Method.',
      'Campaign Promotion Manager.'
    ],
    correctOptionIndex: 1,
  ),
  QuizQuestion(
    questionText: 'When negotiating, why should you get agreement terms in writing before creating content?',
    options: [
      'To show off to other creators.',
      'To ensure both parties are legally protected and clear on deliverables, rates, and usage terms.',
      'Because Flutter requires it.',
      'It is just a formality and not really necessary.'
    ],
    correctOptionIndex: 1,
  ),
];

// ========== Custom Vector Illustration & Certificate Painters ==========

class CertificateIllustration extends StatelessWidget {
  const CertificateIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Spark lines (background)
          CustomPaint(
            size: const Size(280, 110),
            painter: SparksPainter(),
          ),
          
          // Megaphone card on the left
          Positioned(
            left: 55,
            bottom: 12,
            child: Container(
              width: 70,
              height: 55,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Three window dots
                  Padding(
                    padding: const EdgeInsets.only(left: 6, top: 4, bottom: 2),
                    child: Row(
                      children: List.generate(3, (index) => Container(
                        margin: const EdgeInsets.only(right: 3),
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          color: Colors.black38,
                          shape: BoxShape.circle,
                        ),
                      )),
                    ),
                  ),
                  Container(height: 1, color: Colors.black, width: double.infinity),
                  Expanded(
                    child: Row(
                      children: [
                        // Megaphone Custom Painter
                        Container(
                          width: 30,
                          height: 30,
                          margin: const EdgeInsets.only(left: 4),
                          child: CustomPaint(
                            painter: MegaphonePainter(),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4, bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildBar(8, const Color(0xFFEA580C)),
                                _buildBar(14, const Color(0xFFEAB308)),
                                _buildBar(22, const Color(0xFF3B82F6)),
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Silhouette / star badge on the right
          Positioned(
            right: 55,
            bottom: 12,
            child: SizedBox(
              width: 60,
              height: 48,
              child: CustomPaint(
                painter: CollaboratorsPainter(),
              ),
            ),
          ),

          // Center: Hexagon Gold Badge
          Positioned(
            child: CustomPaint(
              size: const Size(76, 85),
              painter: HexagonPainter(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(double height, Color color) {
    return Container(
      width: 4,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
        border: Border.all(color: Colors.black, width: 0.5),
      ),
    );
  }
}

class MegaphonePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final fillBlue = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.fill;

    final fillWhite = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Megaphone main cone body
    final conePath = Path()
      ..moveTo(size.width * 0.25, size.height * 0.45)
      ..lineTo(size.width * 0.65, size.height * 0.25)
      ..lineTo(size.width * 0.65, size.height * 0.65)
      ..lineTo(size.width * 0.25, size.height * 0.45);
    canvas.drawPath(conePath, fillWhite);
    canvas.drawPath(conePath, strokePaint);

    // Megaphone mouth ring (oval on the right)
    final mouthRect = Rect.fromCenter(
      center: Offset(size.width * 0.65, size.height * 0.45),
      width: size.width * 0.1,
      height: size.height * 0.4,
    );
    canvas.drawOval(mouthRect, fillBlue);
    canvas.drawOval(mouthRect, strokePaint);

    // Back piece / driver cup
    final driverRect = Rect.fromCenter(
      center: Offset(size.width * 0.23, size.height * 0.45),
      width: size.width * 0.08,
      height: size.height * 0.18,
    );
    canvas.drawOval(driverRect, fillBlue);
    canvas.drawOval(driverRect, strokePaint);

    // Handle
    final handlePath = Path()
      ..moveTo(size.width * 0.28, size.height * 0.5)
      ..lineTo(size.width * 0.28, size.height * 0.72)
      ..lineTo(size.width * 0.35, size.height * 0.72)
      ..lineTo(size.width * 0.35, size.height * 0.5);
    canvas.drawPath(handlePath, fillBlue);
    canvas.drawPath(handlePath, strokePaint);

    // Sound lines (rays) on the right
    final rayPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.5;

    canvas.drawLine(Offset(size.width * 0.76, size.height * 0.35), Offset(size.width * 0.86, size.height * 0.3), rayPaint);
    canvas.drawLine(Offset(size.width * 0.78, size.height * 0.45), Offset(size.width * 0.88, size.height * 0.45), rayPaint);
    canvas.drawLine(Offset(size.width * 0.76, size.height * 0.55), Offset(size.width * 0.86, size.height * 0.6), rayPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CollaboratorsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final fillWhite = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Draw back collaborator (smaller, top-right)
    final backCenter = Offset(size.width * 0.68, size.height * 0.38);
    final backHeadRadius = size.width * 0.16;
    canvas.drawCircle(backCenter, backHeadRadius, fillWhite);
    canvas.drawCircle(backCenter, backHeadRadius, strokePaint);

    final backBodyPath = Path()
      ..moveTo(size.width * 0.45, size.height * 0.8)
      ..quadraticBezierTo(size.width * 0.45, size.height * 0.52, size.width * 0.68, size.height * 0.52)
      ..quadraticBezierTo(size.width * 0.9, size.height * 0.52, size.width * 0.9, size.height * 0.8);
    canvas.drawPath(backBodyPath, fillWhite);
    canvas.drawPath(backBodyPath, strokePaint);

    // Draw front collaborator (larger, bottom-left)
    final frontCenter = Offset(size.width * 0.36, size.height * 0.45);
    final frontHeadRadius = size.width * 0.2;
    canvas.drawCircle(frontCenter, frontHeadRadius, fillWhite);
    canvas.drawCircle(frontCenter, frontHeadRadius, strokePaint);

    final frontBodyPath = Path()
      ..moveTo(size.width * 0.08, size.height * 0.95)
      ..quadraticBezierTo(size.width * 0.08, size.height * 0.62, size.width * 0.36, size.height * 0.62)
      ..quadraticBezierTo(size.width * 0.64, size.height * 0.62, size.width * 0.64, size.height * 0.95);
    canvas.drawPath(frontBodyPath, fillWhite);
    canvas.drawPath(frontBodyPath, strokePaint);

    // Badge circle in bottom-right
    final badgeCenter = Offset(size.width * 0.72, size.height * 0.72);
    final badgeRadius = size.width * 0.16;
    
    final fillBlue = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(badgeCenter, badgeRadius, fillBlue);
    canvas.drawCircle(badgeCenter, badgeRadius, strokePaint);

    // White star in the badge
    final starPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    final starPath = _calculateStarPath(badgeCenter, badgeRadius * 0.6, badgeRadius * 0.28);
    canvas.drawPath(starPath, starPaint);
  }

  Path _calculateStarPath(Offset center, double outerRadius, double innerRadius) {
    final path = Path();
    final double angle = pi / 5;
    for (int i = 0; i < 10; i++) {
      final double r = (i % 2 == 0) ? outerRadius : innerRadius;
      final double currAngle = i * angle - pi / 2;
      final double x = center.dx + r * cos(currAngle);
      final double y = center.dy + r * sin(currAngle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HexagonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * pi / 180;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Draw background split fill (top half light gold, bottom half dark gold)
    final clipPath = Path()..addPath(path, Offset.zero);
    canvas.save();
    canvas.clipPath(clipPath);
    
    // Top light half
    final topPaint = Paint()..color = const Color(0xFFFFF9E6);
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, center.dy), topPaint);
    
    // Bottom dark half
    final bottomPaint = Paint()..color = const Color(0xFFFED766);
    canvas.drawRect(Rect.fromLTRB(0, center.dy, size.width, size.height), bottomPaint);
    canvas.restore();
    
    // Draw outer thick border
    final borderPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    // Draw inner gold border
    final innerPath = Path();
    final innerRadius = radius - 4;
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * pi / 180;
      final x = center.dx + innerRadius * cos(angle);
      final y = center.dy + innerRadius * sin(angle);
      if (i == 0) {
        innerPath.moveTo(x, y);
      } else {
        innerPath.lineTo(x, y);
      }
    }
    innerPath.close();

    final innerBorderPaint = Paint()
      ..color = const Color(0xFFF5C518)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, borderPaint);
    canvas.drawPath(innerPath, innerBorderPaint);

    // Draw Star in the center (horizontally split shading)
    final starBorderPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final starPath = _calculateStarPath(center, radius * 0.45, radius * 0.2);
    canvas.save();
    canvas.clipPath(starPath);
    
    // Top half of star
    final starTopPaint = Paint()..color = const Color(0xFFFFF1C2);
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, center.dy), starTopPaint);
    
    // Bottom half of star
    final starBottomPaint = Paint()..color = const Color(0xFFFBBF24);
    canvas.drawRect(Rect.fromLTRB(0, center.dy, size.width, size.height), starBottomPaint);
    canvas.restore();
    
    canvas.drawPath(starPath, starBorderPaint);
  }

  Path _calculateStarPath(Offset center, double outerRadius, double innerRadius) {
    final path = Path();
    final double angle = pi / 5;
    for (int i = 0; i < 10; i++) {
      final double r = (i % 2 == 0) ? outerRadius : innerRadius;
      final double currAngle = i * angle - pi / 2;
      final double x = center.dx + r * cos(currAngle);
      final double y = center.dy + r * sin(currAngle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SparksPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);

    // Yellow rays pointing outward around the hexagon
    paint.color = const Color(0xFFFBBF24);
    paint.strokeWidth = 2.0;

    // Draw 3 rays on left top
    canvas.drawLine(Offset(center.dx - 32, center.dy - 28), Offset(center.dx - 40, center.dy - 38), paint);
    canvas.drawLine(Offset(center.dx - 36, center.dy - 12), Offset(center.dx - 46, center.dy - 14), paint);
    canvas.drawLine(Offset(center.dx - 24, center.dy - 36), Offset(center.dx - 29, center.dy - 46), paint);

    // Draw 3 rays on right top
    canvas.drawLine(Offset(center.dx + 32, center.dy - 28), Offset(center.dx + 40, center.dy - 38), paint);
    canvas.drawLine(Offset(center.dx + 36, center.dy - 12), Offset(center.dx + 46, center.dy - 14), paint);
    canvas.drawLine(Offset(center.dx + 24, center.dy - 36), Offset(center.dx + 29, center.dy - 46), paint);

    // Orange plus on the left
    final plusPaint = Paint()
      ..color = const Color(0xFFF97316)
      ..strokeWidth = 2.0;
    final leftPlus = Offset(size.width * 0.16, size.height * 0.58);
    canvas.drawLine(Offset(leftPlus.dx, leftPlus.dy - 5), Offset(leftPlus.dx, leftPlus.dy + 5), plusPaint);
    canvas.drawLine(Offset(leftPlus.dx - 5, leftPlus.dy), Offset(leftPlus.dx + 5, leftPlus.dy), plusPaint);

    // Orange/Red dot on the left
    final dotPaint = Paint()..style = PaintingStyle.fill;
    dotPaint.color = const Color(0xFFEF4444);
    canvas.drawCircle(Offset(size.width * 0.29, size.height * 0.38), 2.5, dotPaint);

    // Blue plus on the right
    plusPaint.color = const Color(0xFF3B82F6);
    final rightPlus = Offset(size.width * 0.81, size.height * 0.48);
    canvas.drawLine(Offset(rightPlus.dx, rightPlus.dy - 5), Offset(rightPlus.dx, rightPlus.dy + 5), plusPaint);
    canvas.drawLine(Offset(rightPlus.dx - 5, rightPlus.dy), Offset(rightPlus.dx + 5, rightPlus.dy), plusPaint);

    // Green dot on the right
    dotPaint.color = const Color(0xFF10B981);
    canvas.drawCircle(Offset(size.width * 0.89, size.height * 0.62), 3.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LaurelWreathPainter extends CustomPainter {
  final bool isLeft;
  LaurelWreathPainter({required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFBBF24)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = const Color(0xFFFBBF24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    if (isLeft) {
      // Curve stem
      path.moveTo(size.width, size.height * 0.95);
      path.quadraticBezierTo(size.width * 0.2, size.height * 0.75, size.width * 0.5, size.height * 0.05);
      canvas.drawPath(path, strokePaint);

      // Draw leaves along the path
      for (double t = 0.15; t <= 0.85; t += 0.18) {
        final x = size.width - (size.width * 0.75 * t);
        final y = size.height * 0.95 - (size.height * 0.9 * t);
        
        // Draw leaf oval
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(-pi / 5);
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 9, height: 4.5),
          paint,
        );
        canvas.restore();
      }
    } else {
      // Curve stem
      path.moveTo(0, size.height * 0.95);
      path.quadraticBezierTo(size.width * 0.8, size.height * 0.75, size.width * 0.5, size.height * 0.05);
      canvas.drawPath(path, strokePaint);

      // Draw leaves along the path
      for (double t = 0.15; t <= 0.85; t += 0.18) {
        final x = size.width * 0.75 * t;
        final y = size.height * 0.95 - (size.height * 0.9 * t);
        
        // Draw leaf oval
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(pi / 5);
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 9, height: 4.5),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SealPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final path = Path();
    
    // Draw scalloped seal
    const int points = 16;
    for (int i = 0; i < points * 2; i++) {
      final angle = i * pi / points;
      final r = (i % 2 == 0) ? radius : radius - 3.5;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final fillPaint = Paint()
      ..color = const Color(0xFFFBBF24)
      ..style = PaintingStyle.fill;
    
    final borderPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);

    // Draw checkmark in the center
    final checkPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final checkPath = Path()
      ..moveTo(center.dx - radius * 0.3, center.dy)
      ..lineTo(center.dx - radius * 0.05, center.dy + radius * 0.22)
      ..lineTo(center.dx + radius * 0.35, center.dy - radius * 0.25);

    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


