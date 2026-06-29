import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/app_card.dart';

class AdminVerificationRequestsScreen extends ConsumerStatefulWidget {
  const AdminVerificationRequestsScreen({super.key});

  @override
  ConsumerState<AdminVerificationRequestsScreen> createState() => _AdminVerificationRequestsScreenState();
}

class _AdminVerificationRequestsScreenState extends ConsumerState<AdminVerificationRequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadRequests();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.client
          .from('verification_requests')
          .select('*, profile:profiles!verification_requests_user_id_fkey(*)')
          .order('created_at', ascending: false);

      setState(() {
        _requests = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('[ADMIN VERIFY] Error loading verification requests: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _approveRequest(Map<String, dynamic> request) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final reqId = request['id'] as String;
    final targetUserId = request['user_id'] as String;

    try {
      await SupabaseService.client.from('verification_requests').update({
        'status': 'approved',
        'reviewed_by': user.id,
      }).eq('id', reqId);

      await SupabaseService.client.from('profiles').update({
        'is_verified': true,
      }).eq('id', targetUserId);

      _loadRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request approved. User has been verified!')),
        );
      }
    } catch (e) {
      debugPrint('[ADMIN VERIFY] Error approving request: $e');
    }
  }

  void _showRejectDialog(Map<String, dynamic> request) {
    final noteCtrl = TextEditingController();
    final reqId = request['id'] as String;
    final targetUserId = request['user_id'] as String;
    final user = ref.read(authProvider).user;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Verification Request'),
        content: TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(
            labelText: 'Admin Note / Reason',
            hintText: 'Enter reason why this was rejected...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (user == null) return;
              try {
                await SupabaseService.client.from('verification_requests').update({
                  'status': 'rejected',
                  'admin_note': noteCtrl.text.trim(),
                  'reviewed_by': user.id,
                }).eq('id', reqId);

                await SupabaseService.client.from('profiles').update({
                  'is_verified': false,
                }).eq('id', targetUserId);

                _loadRequests();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Verification request rejected.')),
                  );
                }
              } catch (e) {
                debugPrint('[ADMIN VERIFY] Error rejecting: $e');
              }
            },
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _viewDocument(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      final ext = url.split('.').last.toLowerCase();
      if (['jpg', 'jpeg', 'png'].contains(ext)) {
        context.push('/image-viewer', extra: {
          'urls': [url],
          'initialIndex': 0,
          'title': 'ID Document',
        });
      } else {
        // Fallback to launch web view/browser
        context.push('/image-viewer', extra: {
          'urls': [url],
          'initialIndex': 0,
          'title': 'ID Document',
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pendingList = _requests.where((r) => r['status'] == 'pending').toList();
    final reviewedList = _requests.where((r) => r['status'] != 'pending').toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : const Color(0xFFF9FAFB),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56 + 48 + AppSpacing.pageMarginVertical),
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.appBarMarginHorizontal,
            right: AppSpacing.appBarMarginHorizontal,
            top: AppSpacing.pageMarginVertical,
          ),
          child: AppBar(
            centerTitle: false,
            titleSpacing: 0,
            title: Text(
              'Verification Portal',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            actions: [
              IconButton(
                icon: const Icon(Iconsax.notification, size: 22),
                onPressed: () => context.push('/admin/notifications'),
              ),
              IconButton(
                icon: const Icon(Iconsax.setting_2, size: 22),
                onPressed: () => context.push('/admin/settings'),
              ),
            ],
            bottom: TabBar(
              controller: _tabCtrl,
              tabs: [
                Tab(text: 'Pending (${pendingList.length})'),
                Tab(text: 'Reviewed (${reviewedList.length})'),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildRequestList(pendingList, isPending: true),
                _buildRequestList(reviewedList, isPending: false),
              ],
            ),
    );
  }

  Widget _buildRequestList(List<Map<String, dynamic>> list, {required bool isPending}) {
    if (list.isEmpty) {
      return const AppEmptyState(icon: Iconsax.teacher, title: 'No requests here');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final r = list[i];
        final profile = r['profile'] as Map<String, dynamic>? ?? {};
        final displayName = profile['display_name'] ?? 'User';
        final userRole = r['role'] ?? 'influencer';
        final notes = r['notes'] ?? 'No notes submitted.';
        final links = (r['submitted_links'] as List?)?.cast<String>() ?? [];
        final status = r['status'] as String? ?? 'pending';
        final adminNote = r['admin_note'];
        final date = r['created_at'] != null 
            ? DateFormat('MMM d, h:mm a').format(DateTime.parse(r['created_at'])) 
            : '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppAvatar(
                      url: profile['avatar_url'],
                      fallbackText: displayName,
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayName, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                          Text('${userRole.toString().toUpperCase()}  •  $date', style: AppTextStyles.captionSm),
                        ],
                      ),
                    ),
                    if (!isPending)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: status == 'approved' ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: status == 'approved' ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('APPLICANT NOTES', style: AppTextStyles.overline),
                const SizedBox(height: 4),
                Text(notes, style: AppTextStyles.body),
                const SizedBox(height: 14),

                if (links.isNotEmpty) ...[
                  Text('ATTACHED DOCUMENTS', style: AppTextStyles.overline),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: links.map((url) {
                      return ActionChip(
                        avatar: const Icon(Iconsax.document, size: 16),
                        label: const Text('View Document'),
                        onPressed: () => _viewDocument(url),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                if (!isPending && adminNote != null) ...[
                  const Divider(),
                  const SizedBox(height: 6),
                  Text('REJECTION REASON', style: AppTextStyles.overline.copyWith(color: Colors.red)),
                  const SizedBox(height: 4),
                  Text(adminNote.toString(), style: AppTextStyles.body.copyWith(color: Colors.red.shade400)),
                  const SizedBox(height: 10),
                ],

                if (isPending) ...[
                  const Divider(),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () => _showRejectDialog(r),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.withValues(alpha: 0.1),
                          foregroundColor: Colors.red,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        ),
                        child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => _approveRequest(r),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.purple,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        ),
                        child: const Text('Approve Badge', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
