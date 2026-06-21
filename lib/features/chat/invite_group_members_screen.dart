import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/shared_widgets.dart';

class InviteGroupMembersScreen extends ConsumerStatefulWidget {
  final String roomId;
  final List<Map<String, dynamic>> existingMembers;

  const InviteGroupMembersScreen({
    super.key,
    required this.roomId,
    required this.existingMembers,
  });

  @override
  ConsumerState<InviteGroupMembersScreen> createState() => _InviteGroupMembersScreenState();
}

class _InviteGroupMembersScreenState extends ConsumerState<InviteGroupMembersScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _inviteable = [];
  List<Map<String, dynamic>> _filtered = [];
  final List<Map<String, dynamic>> _selectedUsers = [];
  bool _loading = true;
  bool _submitting = false;
  final _chatService = ChatService();

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final user = ref.read(authProvider).user;
      if (user == null) return;

      final allProfilesRes = await SupabaseService.client
          .from('profiles')
          .select('id, display_name, avatar_url, role, niche, follower_count, location, is_verified')
          .neq('id', user.id);
      
      final allProfiles = List<Map<String, dynamic>>.from(allProfilesRes);
      final existingUserIds = widget.existingMembers.map((m) => m['user_id'] as String).toSet();
      
      final inviteable = allProfiles.where((p) => !existingUserIds.contains(p['id'])).toList();

      if (mounted) {
        setState(() {
          _inviteable = inviteable;
          _filtered = inviteable;
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading users to invite: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = _inviteable;
      } else {
        _filtered = _inviteable.where((p) {
          final name = (p['display_name'] ?? '').toString().toLowerCase();
          final role = (p['role'] ?? '').toString().toLowerCase();
          final location = (p['location'] ?? '').toString().toLowerCase();
          return name.contains(query) || role.contains(query) || location.contains(query);
        }).toList();
      }
    });
  }

  void _toggleSelect(Map<String, dynamic> user) {
    setState(() {
      final isSelected = _selectedUsers.any((u) => u['id'] == user['id']);
      if (isSelected) {
        _selectedUsers.removeWhere((u) => u['id'] == user['id']);
      } else {
        _selectedUsers.add(user);
      }
    });
  }

  Future<void> _submit() async {
    if (_selectedUsers.isEmpty) return;
    setState(() => _submitting = true);
    
    try {
      for (final user in _selectedUsers) {
        await _chatService.inviteUserToGroup(widget.roomId, user['id']);
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error inviting users: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to invite: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Invite Members',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Input Container
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface : AppColors.surface2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Iconsax.search_normal_1, color: AppColors.textMuted, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: AppTextStyles.body,
                      decoration: InputDecoration(
                        hintText: 'Search by name, role or location...',
                        hintStyle: AppTextStyles.caption,
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    GestureDetector(
                      onTap: () => _searchCtrl.clear(),
                      child: Icon(Icons.cancel_rounded, color: AppColors.textMuted, size: 18),
                    ),
                ],
              ),
            ),
          ),

          // Horizontal Selected Row (Dynamic Height)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _selectedUsers.isEmpty ? 0 : 80,
            child: _selectedUsers.isEmpty
                ? const SizedBox.shrink()
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _selectedUsers.length,
                    itemBuilder: (context, i) {
                      final user = _selectedUsers[i];
                      return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AppAvatar(
                                  url: user['avatar_url'],
                                  fallbackText: user['display_name'] ?? 'U',
                                  size: 44,
                                  onTap: () => _toggleSelect(user),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 50,
                                  child: Text(
                                    (user['display_name'] ?? '').toString().split(' ')[0],
                                    style: AppTextStyles.captionSm.copyWith(fontSize: 10),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            Positioned(
                              top: -2,
                              right: -2,
                              child: GestureDetector(
                                onTap: () => _toggleSelect(user),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.surface : Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.cancel_rounded,
                                    color: AppColors.error,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          if (_selectedUsers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: AppColors.border, height: 1),
            ),

          // User List
          Expanded(
            child: _loading
                ? ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: 5,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, __) => const ShimmerGenericListTile(),
                  )
                : _filtered.isEmpty
                    ? AppEmptyState(
                        icon: Iconsax.user_search,
                        title: 'No creators found',
                        subtitle: _searchCtrl.text.isEmpty
                            ? 'All existing members are already in the group.'
                            : 'No matching users found for "${_searchCtrl.text}"',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final p = _filtered[i];
                          final isSelected = _selectedUsers.any((u) => u['id'] == p['id']);
                          
                          // Format descriptive subtitle
                          String subtitle = '';
                          if (p['role'] == 'influencer') {
                            final niches = (p['niche'] as List?)?.cast<String>() ?? [];
                            final fc = p['follower_count'] ?? 0;
                            final fcText = fc >= 1000 ? '${(fc / 1000).toStringAsFixed(0)}K' : '$fc';
                            subtitle = 'Influencer • $fcText followers${niches.isNotEmpty ? ' • ${niches.take(1).join()}' : ''}';
                          } else {
                            subtitle = 'Brand • ${p['location'] ?? 'Global'}';
                          }

                          return GestureDetector(
                            onTap: () => _toggleSelect(p),
                            behavior: HitTestBehavior.opaque,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? AppColors.accent.withOpacity(isDark ? 0.08 : 0.04) 
                                    : AppColors.surface,
                                border: Border.all(
                                  color: isSelected ? AppColors.accent : AppColors.border,
                                  width: isSelected ? 1.5 : 1,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  AppAvatar(
                                    url: p['avatar_url'],
                                    fallbackText: p['display_name'] ?? 'U',
                                    size: 40,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                p['display_name'] ?? 'User',
                                                style: AppTextStyles.label.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (p['is_verified'] == true) ...[
                                              const SizedBox(width: 4),
                                              const VerificationBadge(size: 14),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          subtitle,
                                          style: AppTextStyles.captionSm,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Premium Custom Tick Icon
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected ? AppColors.accent : Colors.transparent,
                                      border: Border.all(
                                        color: isSelected ? AppColors.accent : AppColors.textMuted.withOpacity(0.4),
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          
          // Sticky Bottom Invitation Bar
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14141E) : Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: AppButton(
              label: _selectedUsers.isEmpty
                  ? 'Select creators to invite'
                  : 'Invite Selected (${_selectedUsers.length})',
              onTap: _selectedUsers.isEmpty ? null : _submit,
              isLoading: _submitting,
            ),
          ),
        ],
      ),
    );
  }
}
