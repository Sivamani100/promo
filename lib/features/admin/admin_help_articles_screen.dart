import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/app_card.dart';

class AdminHelpArticlesScreen extends StatefulWidget {
  const AdminHelpArticlesScreen({super.key});

  @override
  State<AdminHelpArticlesScreen> createState() => _AdminHelpArticlesScreenState();
}

class _AdminHelpArticlesScreenState extends State<AdminHelpArticlesScreen> {
  List<Map<String, dynamic>> _articles = [];
  bool _loading = true;
  String _selectedRoleFilter = 'all'; // all, brand, influencer

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  Future<void> _loadArticles() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.client
          .from('help_articles')
          .select()
          .order('created_at', ascending: false);

      setState(() {
        _articles = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('[HELP ARTICLES] Error loading: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _togglePublish(String id, bool currentStatus) async {
    try {
      await SupabaseService.client.from('help_articles').update({
        'is_published': !currentStatus,
      }).eq('id', id);
      _loadArticles();
    } catch (e) {
      debugPrint('[HELP ARTICLES] Error updating publish state: $e');
    }
  }

  Future<void> _deleteArticle(String id) async {
    try {
      await SupabaseService.client.from('help_articles').delete().eq('id', id);
      _loadArticles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Help article deleted successfully.')),
        );
      }
    } catch (e) {
      debugPrint('[HELP ARTICLES] Error deleting: $e');
    }
  }

  Future<void> _saveArticle({
    String? id,
    required String title,
    required String content,
    required String category,
    required String targetRole,
    required bool isPublished,
  }) async {
    try {
      final sb = SupabaseService.client;
      final payload = {
        'title': title,
        'content': content,
        'category': category,
        'target_role': targetRole,
        'is_published': isPublished,
      };

      if (id == null) {
        // Insert
        await sb.from('help_articles').insert(payload);
      } else {
        // Update
        await sb.from('help_articles').update(payload).eq('id', id);
      }

      _loadArticles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(id == null ? 'Help article created!' : 'Help article updated!')),
        );
      }
    } catch (e) {
      debugPrint('[HELP ARTICLES] Error saving: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save help article: $e')),
        );
      }
    }
  }

  void _showArticleFormDialog([Map<String, dynamic>? article]) {
    final titleCtrl = TextEditingController(text: article?['title'] ?? '');
    final contentCtrl = TextEditingController(text: article?['content'] ?? '');
    final categoryCtrl = TextEditingController(text: article?['category'] ?? 'General');
    
    String targetRole = article?['target_role'] ?? 'all';
    bool isPublished = article?['is_published'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(article == null ? 'New Support Article' : 'Edit Support Article'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Article Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: categoryCtrl,
                  decoration: const InputDecoration(labelText: 'Category', hintText: 'e.g., Accounts, Campaign, Payments'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: targetRole,
                  decoration: const InputDecoration(labelText: 'Target Audience'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Users')),
                    DropdownMenuItem(value: 'brand', child: Text('Brands Only')),
                    DropdownMenuItem(value: 'influencer', child: Text('Creators Only')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => targetRole = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Article Body (Markdown supported)',
                    hintText: 'Enter complete guides & support documents...',
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Publish Immediately'),
                  subtitle: const Text('Make visible to users in app'),
                  value: isPublished,
                  onChanged: (val) {
                    setDialogState(() => isPublished = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (titleCtrl.text.isEmpty || contentCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                _saveArticle(
                  id: article?['id'],
                  title: titleCtrl.text,
                  content: contentCtrl.text,
                  category: categoryCtrl.text,
                  targetRole: targetRole,
                  isPublished: isPublished,
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredArticles = _articles.where((a) {
      if (_selectedRoleFilter == 'all') return true;
      return a['target_role'] == _selectedRoleFilter;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : const Color(0xFFF9FAFB),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMarginHorizontal),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leadingWidth: 40,
            leading: IconButton(
              icon: Icon(Iconsax.arrow_left, color: isDark ? Colors.white : Colors.black),
              onPressed: () => context.pop(),
            ),
            title: Text(
              'HELP ARTICLES',
              style: AppTextStyles.h3.copyWith(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            actions: [
              IconButton(
                icon: const Icon(Iconsax.add_circle),
                onPressed: () => _showArticleFormDialog(),
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['all', 'brand', 'influencer'].map((role) {
                        final isSelected = _selectedRoleFilter == role;
                        String label = 'ALL AUDIENCES';
                        if (role == 'brand') label = 'BRANDS';
                        if (role == 'influencer') label = 'CREATORS';

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(label),
                            selected: isSelected,
                            onSelected: (val) {
                              setState(() => _selectedRoleFilter = role);
                            },
                            selectedColor: AppColors.purple.withValues(alpha: 0.15),
                            checkmarkColor: AppColors.purple,
                            labelStyle: TextStyle(
                              color: isSelected ? AppColors.purple : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 11,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Articles List
                  Expanded(
                    child: filteredArticles.isEmpty
                        ? const Center(
                            child: AppEmptyState(
                              icon: Iconsax.document_text,
                              title: 'No articles in this category',
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredArticles.length,
                            itemBuilder: (context, i) {
                              final a = filteredArticles[i];
                              final id = a['id'] as String;
                              final title = a['title'] as String? ?? '';
                              final content = a['content'] as String? ?? '';
                              final category = a['category'] as String? ?? 'General';
                              final targetRole = a['target_role'] as String? ?? 'all';
                              final isPublished = a['is_published'] as bool? ?? false;
                              final views = a['view_count'] as int? ?? 0;
                              final helpful = a['helpful_count'] as int? ?? 0;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: AppCard(
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.purple.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(100),
                                            ),
                                            child: Text(
                                              category.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                                color: AppColors.purple,
                                              ),
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              const Icon(Iconsax.eye, size: 14, color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Text('$views', style: AppTextStyles.captionSm),
                                              const SizedBox(width: 12),
                                              const Icon(Iconsax.like_1, size: 14, color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Text('$helpful', style: AppTextStyles.captionSm),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        title,
                                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        content,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.caption,
                                      ),
                                      const Divider(height: 24),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                isPublished ? 'PUBLISHED' : 'DRAFT',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: isPublished ? Colors.green : Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Switch(
                                                value: isPublished,
                                                onChanged: (val) => _togglePublish(id, isPublished),
                                                activeColor: Colors.green,
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(Iconsax.edit, size: 18, color: Colors.grey),
                                                onPressed: () => _showArticleFormDialog(a),
                                              ),
                                              IconButton(
                                                icon: const Icon(Iconsax.trash, size: 18, color: Colors.red),
                                                onPressed: () => _deleteArticle(id),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
