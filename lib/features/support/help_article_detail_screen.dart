import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/services/supabase_service.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/app_card.dart';

class HelpArticleDetailScreen extends ConsumerStatefulWidget {
  final String articleId;
  const HelpArticleDetailScreen({super.key, required this.articleId});

  @override
  ConsumerState<HelpArticleDetailScreen> createState() => _HelpArticleDetailScreenState();
}

class _HelpArticleDetailScreenState extends ConsumerState<HelpArticleDetailScreen> {
  Map<String, dynamic>? _article;
  List<Map<String, dynamic>> _relatedArticles = [];
  bool _loading = true;
  bool _hasFeedback = false;
  bool _feedbackSubmitted = false;
  final _feedbackCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadArticle();
  }

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadArticle() async {
    setState(() => _loading = true);
    try {
      final client = SupabaseService.client;
      // 1. Fetch main article
      final articleData = await client
          .from('help_articles')
          .select()
          .eq('id', widget.articleId)
          .single();

      if (articleData != null) {
        // 2. Increment view count
        await client
            .from('help_articles')
            .update({'view_count': (articleData['view_count'] ?? 0) + 1})
            .eq('id', widget.articleId);

        // 3. Fetch 3 related articles from same category (excluding current)
        final relatedData = await client
            .from('help_articles')
            .select('id, title, category')
            .eq('category', articleData['category'])
            .neq('id', widget.articleId)
            .eq('is_published', true)
            .limit(3);

        if (mounted) {
          setState(() {
            _article = articleData;
            _relatedArticles = List<Map<String, dynamic>>.from(relatedData);
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[SUPPORT] Error loading help article: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submitHelpfulFeedback(bool helpful) async {
    final user = ref.read(authProvider).user;
    if (user == null || _article == null) return;

    try {
      final client = SupabaseService.client;
      
      // Update helpful count in help_articles table
      if (helpful) {
        await client
            .from('help_articles')
            .update({'helpful_count': (_article!['helpful_count'] ?? 0) + 1})
            .eq('id', widget.articleId);
      }

      // Add feedback record
      await client.from('feedback').insert({
        'user_id': user.id,
        'type': 'article_feedback',
        'score': helpful ? 1 : 0,
        'comment': helpful ? 'Marked as helpful' : _feedbackCtrl.text.trim(),
        'metadata': {'article_id': widget.articleId, 'article_title': _article!['title']},
      });

      if (mounted) {
        setState(() {
          _feedbackSubmitted = true;
          _hasFeedback = false;
        });
      }
    } catch (e) {
      debugPrint('[SUPPORT] Failed to submit feedback: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_article == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Article not found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_article!['title'], style: AppTextStyles.h2),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space16, vertical: DesignTokens.space24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.purple.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
                ),
                child: Text(
                  _article!['category'].toString().replaceAll('_', ' ').toUpperCase(),
                  style: AppTextStyles.overline.copyWith(color: AppColors.purple),
                ),
              ),
              const SizedBox(height: 16),
              
              // Article Content
              MarkdownBody(
                data: _article!['content'] ?? '',
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: AppTextStyles.bodyLg.copyWith(color: AppColors.textPrimary),
                  h1: AppTextStyles.h1.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                  h2: AppTextStyles.h2.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                  h3: AppTextStyles.h3.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                  listBullet: AppTextStyles.bodyLg.copyWith(color: AppColors.textPrimary),
                ),
              ),
              
              const SizedBox(height: 48),
              const Divider(),
              const SizedBox(height: 24),
              
              // Helpful prompt
              Center(
                child: _feedbackSubmitted
                    ? Column(
                        children: [
                          const Icon(Icons.check_circle_outline, color: AppColors.success, size: 36),
                          const SizedBox(height: 8),
                          Text('Thank you for your feedback!', style: AppTextStyles.h3),
                        ],
                      )
                    : Column(
                        children: [
                          Text('Was this article helpful?', style: AppTextStyles.h3),
                          const SizedBox(height: 16),
                          if (!_hasFeedback)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _submitHelpfulFeedback(true),
                                  icon: const Icon(Icons.thumb_up_alt_outlined, size: 18),
                                  label: const Text('Yes'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _hasFeedback = true;
                                    });
                                  },
                                  icon: const Icon(Icons.thumb_down_alt_outlined, size: 18),
                                  label: const Text('No'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                                  ),
                                ),
                              ],
                            )
                          else
                            Column(
                              children: [
                                AppTextField(
                                  label: 'How can we improve this article?',
                                  hint: 'Tell us what was missing...',
                                  controller: _feedbackCtrl,
                                  maxLines: 3,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () => setState(() => _hasFeedback = false),
                                      child: const Text('Cancel'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () => _submitHelpfulFeedback(false),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.purple,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Submit'),
                                    ),
                                  ],
                                )
                              ],
                            ),
                        ],
                      ),
              ),

              const SizedBox(height: 48),
              if (_relatedArticles.isNotEmpty) ...[
                Text('Related Articles', style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _relatedArticles.length,
                  itemBuilder: (context, index) {
                    final item = _relatedArticles[index];
                    return AppCard(
                      onTap: () {
                        context.pushReplacement('/support/article/${item['id']}');
                      },
                      padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space16, vertical: DesignTokens.space12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item['title'] ?? '',
                              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Icon(Iconsax.arrow_right_1, size: 18, color: AppColors.textMuted),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
