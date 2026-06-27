import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/staggered_list_item.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _articles = [];
  bool _loadingArticles = true;
  String _searchQuery = '';
  bool _creatingChat = false;

  @override
  void initState() {
    super.initState();
    _loadArticles();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadArticles() async {
    setState(() => _loadingArticles = true);
    try {
      final client = SupabaseService.client;
      final role = ref.read(authProvider).role;

      // Fetch all published articles
      final query = client
          .from('help_articles')
          .select()
          .eq('is_published', true);

      final data = await query;
      
      if (mounted) {
        setState(() {
          // Filter articles based on target role: either null or matching user role
          _articles = List<Map<String, dynamic>>.from(data).where((art) {
            final targetRole = art['target_role'];
            return targetRole == null || targetRole == role;
          }).toList();
          _loadingArticles = false;
        });
      }
    } catch (e) {
      debugPrint('[SUPPORT] Error loading articles: $e');
      if (mounted) {
        setState(() => _loadingArticles = false);
      }
    }
  }

  Future<void> _openSupportChat() async {
    final user = ref.read(authProvider).user;
    final role = ref.read(authProvider).role;
    if (user == null || _creatingChat) return;

    setState(() => _creatingChat = true);

    try {
      final adminId = '259172c1-8707-4a31-b9ba-2fc81ebbba47';
      final brandId = role == 'brand' ? user.id : adminId;
      final influencerId = role == 'influencer' ? user.id : adminId;

      final room = await ChatService().getOrCreate1to1Room(
        brandId: brandId,
        influencerId: influencerId,
      );

      if (mounted) {
        context.push('/chat/room/${room['id']}');
      }
    } catch (e) {
      debugPrint('[SUPPORT] Error opening support chat: $e');
    } finally {
      if (mounted) {
        setState(() => _creatingChat = false);
      }
    }
  }

  void _emailSupport() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@promo.arkio.in',
      queryParameters: {
        'subject': 'Support Request - Promo App',
      },
    );
    try {
      await url_launcher.launchUrl(emailLaunchUri);
    } catch (e) {
      debugPrint('[SUPPORT] Failed to launch email client: $e');
    }
  }

  void _launchCommunityUrl(String url) async {
    try {
      await url_launcher.launchUrl(Uri.parse(url), mode: url_launcher.LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[SUPPORT] Failed to launch URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Filter articles dynamically based on search query
    final filteredArticles = _articles.where((art) {
      if (_searchQuery.isEmpty) return true;
      final title = art['title'].toString().toLowerCase();
      final content = art['content'].toString().toLowerCase();
      return title.contains(_searchQuery) || content.contains(_searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Help & Support'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space16, vertical: DesignTokens.space24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search input
              TextField(
                controller: _searchCtrl,
                style: AppTextStyles.body,
                decoration: InputDecoration(
                  hintText: 'Search help articles...',
                  prefixIcon: const Icon(Iconsax.search_normal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(100)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
              ),
              const SizedBox(height: 28),

              // Help Articles List
              Text('POPULAR ARTICLES', style: AppTextStyles.overline),
              const SizedBox(height: 12),
              if (_loadingArticles)
                const Center(child: CircularProgressIndicator())
              else if (filteredArticles.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text('No articles found matching search.', style: AppTextStyles.bodySm.copyWith(fontStyle: FontStyle.italic)),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredArticles.length,
                  itemBuilder: (context, idx) {
                    final art = filteredArticles[idx];
                    return StaggeredListItem(
                      index: idx,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppCard(
                          onTap: () {
                            context.push('/support/article/${art['id']}');
                          },
                          padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space16, vertical: DesignTokens.space14),
                          child: Row(
                            children: [
                              Icon(Iconsax.info_circle, color: AppColors.purple, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  art['title'] ?? '',
                                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Icon(Iconsax.arrow_right_1, color: AppColors.textMuted, size: 18),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              
              const SizedBox(height: 32),
              
              // Contact Section
              Text('CONTACT SUPPORT', style: AppTextStyles.overline),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppCard(
                      onTap: _openSupportChat,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          Icon(Iconsax.message_programming, color: AppColors.purple, size: 28),
                          const SizedBox(height: 12),
                          _creatingChat
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text('Chat with us', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Typical reply: < 2 hrs', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AppCard(
                      onTap: _emailSupport,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          Icon(Iconsax.direct_send, color: AppColors.purple, size: 28),
                          const SizedBox(height: 12),
                          Text('Email support', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Typical reply: 24 hrs', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 36),
              
              // Community Section
              Text('JOIN OUR COMMUNITY', style: AppTextStyles.overline),
              const SizedBox(height: 12),
              AppCard(
                onTap: () => _launchCommunityUrl('https://discord.gg/promoapp'),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    const Icon(Icons.discord, color: Color(0xFF5865F2), size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Join our Discord', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                          Text('Connect with creators and share tips!', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    Icon(Iconsax.arrow_right_1, color: AppColors.textMuted, size: 18),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                onTap: () => _launchCommunityUrl('https://instagram.com/promo.arkio.in'),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/Social media icons/Instagram logo.png',
                      width: 24,
                      height: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Follow on Instagram', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                          Text('Get product updates and see campaigns.', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    Icon(Iconsax.arrow_right_1, color: AppColors.textMuted, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}