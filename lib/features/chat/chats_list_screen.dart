import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/shared_widgets.dart';

class ChatsListScreen extends ConsumerStatefulWidget {
  final String role;
  const ChatsListScreen({super.key, required this.role});

  @override
  ConsumerState<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends ConsumerState<ChatsListScreen> {
  List<Map<String, dynamic>> _rooms = [];
  Map<String, Map<String, dynamic>?> _lastMessages = {};
  Map<String, int> _unreadCounts = {};
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  String _selectedFilter = 'All';

  // Realtime subscriptions
  RealtimeChannel? _messagesSubscription;
  final Map<String, RealtimeChannel> _typingChannels = {};
  final Map<String, String> _typingNames = {};
  Timer? _onlineTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeToMessages();
    _onlineTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _onlineTimer?.cancel();
    if (_messagesSubscription != null) {
      try {
        SupabaseService.client.removeChannel(_messagesSubscription!);
      } catch (e) {
        print('Error removing message channel: $e');
      }
    }
    for (final channel in _typingChannels.values) {
      try {
        SupabaseService.client.removeChannel(channel);
      } catch (e) {
        print('Error removing typing channel: $e');
      }
    }
    super.dispose();
  }

  Future<void> _load() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      final data = await ChatService().getRooms(user.id, widget.role);

      final msgMap = <String, Map<String, dynamic>?>{};
      final unreadMap = <String, int>{};

      for (final room in data) {
        final roomId = room['id'] as String;
        msgMap[roomId] = await ChatService().getLastMessage(roomId);
        unreadMap[roomId] = await ChatService().getUnreadCountForRoom(roomId, user.id);
      }

      if (mounted) {
        setState(() {
          _rooms = data;
          _lastMessages = msgMap;
          _unreadCounts = unreadMap;
          _loading = false;
        });
        _subscribeToTyping(data);
      }
    } catch (e) {
      print('Error loading rooms: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeToMessages() {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    if (_messagesSubscription != null) {
      try {
        SupabaseService.client.removeChannel(_messagesSubscription!);
      } catch (e) {
        print('Error removing message channel: $e');
      }
      _messagesSubscription = null;
    }

    try {
      _messagesSubscription = SupabaseService.client
          .channel('chats_list_messages_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              _load();
            },
          )
          .subscribe();
    } catch (e) {
      print('Error subscribing to messages changes: $e');
    }
  }

  void _subscribeToTyping(List<Map<String, dynamic>> rooms) {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final activeIds = rooms.map((r) => r['id'] as String).toSet();

    // Remove channels no longer in the rooms list
    final removedIds = _typingChannels.keys.where((id) => !activeIds.contains(id)).toList();
    for (final id in removedIds) {
      final channel = _typingChannels.remove(id);
      if (channel != null) {
        try {
          SupabaseService.client.removeChannel(channel);
        } catch (e) {
          print('Error removing typing channel: $e');
        }
      }
      _typingNames.remove(id);
    }

    // Subscribe to new channels only
    for (final room in rooms) {
      final roomId = room['id'] as String;
      if (_typingChannels.containsKey(roomId)) continue; // skip existing

      try {
        final channel = SupabaseService.client.channel('typing:$roomId');
        channel.onBroadcast(
          event: 'typing',
          callback: (payload) {
            final senderId = payload['senderId'] as String?;
            final senderName = payload['senderName'] as String?;
            final isTyping = payload['isTyping'] as bool?;

            if (senderId != user.id && mounted) {
              setState(() {
                if (isTyping == true) {
                  _typingNames[roomId] = senderName ?? 'Typing...';
                } else {
                  _typingNames.remove(roomId);
                }
              });
            }
          },
        ).subscribe();
        _typingChannels[roomId] = channel;
      } catch (e) {
        print('Error setting up typing channel: $e');
      }
    }
  }

  void _showGroupCreationFABOptions() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151522) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.accent.withOpacity(0.1),
                    child: Icon(Iconsax.user, color: AppColors.accent),
                  ),
                  title: const Text('New Chat', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Start a 1-to-1 conversation with an influencer'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showNewChatSelectionDialog();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.purple.withOpacity(0.1),
                    child: Icon(Iconsax.people, color: AppColors.purple),
                  ),
                  title: const Text('New Group', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Create a custom group with multiple members'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showGroupWizard(isCampaign: false);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.success.withOpacity(0.1),
                    child: Icon(Iconsax.briefcase, color: AppColors.success),
                  ),
                  title: const Text('Campaign Group', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Create a group chat specifically for a campaign'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showGroupWizard(isCampaign: true);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showNewChatSelectionDialog() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    showPremiumDialog(
      context: context,
      title: 'New 1-to-1 Chat',
      icon: Iconsax.message_add,
      content: FutureBuilder<List<Map<String, dynamic>>>(
        future: SupabaseService.client
            .from('profiles')
            .select('id, display_name, role, avatar_url')
            .neq('id', user.id)
            .then((res) => List<Map<String, dynamic>>.from(res)),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final profiles = snapshot.data ?? [];
          if (profiles.isEmpty) {
            return const Text('No profiles available to chat with.');
          }

          return SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: profiles.length,
              itemBuilder: (ctx, idx) {
                final profile = profiles[idx];
                final display = profile['display_name'] ?? 'User';
                final role = profile['role'] ?? 'User';
                return ListTile(
                  leading: AppAvatar(
                    url: profile['avatar_url'],
                    fallbackText: display,
                    size: 36,
                  ),
                  title: Text(display, style: AppTextStyles.body),
                  subtitle: Text(role.toUpperCase(), style: AppTextStyles.captionSm),
                  onTap: () async {
                    Navigator.pop(ctx);
                    _startOneToOneChat(profile['id'] as String);
                  },
                );
              },
            ),
          );
        },
      ),
      actionsBuilder: (dialogCtx) => [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Future<void> _startOneToOneChat(String otherUserId) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      final room = await ChatService().getOrCreate1to1Room(
        brandId: user.id,
        influencerId: otherUserId,
      );
      _load();
      if (mounted) {
        final basePath = widget.role == 'brand' ? '/brand' : '/influencer';
        context.push('$basePath/chats/${room['id']}');
      }
    } catch (e) {
      print('Error starting 1-to-1 chat: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _showGroupWizard({required bool isCampaign}) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    String? selectedCampaignId;
    String? selectedCampaignTitle;
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    List<Map<String, dynamic>> allUsers = [];
    final selectedUserIds = <String>{};
    bool loadingUsers = true;

    if (isCampaign) {
      final campaigns = await SupabaseService.client
          .from('cards')
          .select('id, title')
          .eq('brand_id', user.id)
          .then((res) => List<Map<String, dynamic>>.from(res));

      if (campaigns.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You must have an active campaign card to link a campaign group.')),
          );
        }
        return;
      }

      if (mounted) {
        final selectedCamp = await showPremiumDialog<Map<String, dynamic>>(
          context: context,
          title: 'Select Campaign',
          icon: Iconsax.briefcase,
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: campaigns.length,
              itemBuilder: (ctx, idx) {
                final camp = campaigns[idx];
                return ListTile(
                  title: Text(camp['title'] ?? '', style: AppTextStyles.body),
                  onTap: () => Navigator.pop(ctx, camp),
                );
              },
            ),
          ),
          actionsBuilder: (dialogCtx) => [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        );

        if (selectedCamp == null) return;
        selectedCampaignId = selectedCamp['id'] as String;
        selectedCampaignTitle = selectedCamp['title'] as String;
        nameCtrl.text = '$selectedCampaignTitle Group';
      }
    }

    try {
      final res = await SupabaseService.client
          .from('profiles')
          .select('id, display_name, role, avatar_url')
          .neq('id', user.id);
      allUsers = List<Map<String, dynamic>>.from(res);
      loadingUsers = false;
    } catch (e) {
      print('Error loading users for group: $e');
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setWizardState) {
            return Dialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isCampaign ? 'New Campaign Group' : 'New Custom Group',
                          style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      onChanged: (_) => setWizardState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Group Name',
                        hintText: 'e.g., Summer Campaign 2026',
                        labelStyle: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                        floatingLabelStyle: TextStyle(color: AppColors.accent),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppColors.borderSubtle),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppColors.accent, width: 2),
                        ),
                        filled: true,
                        fillColor: AppColors.surface2,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Group details and info...',
                        labelStyle: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                        floatingLabelStyle: TextStyle(color: AppColors.accent),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppColors.borderSubtle),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppColors.accent, width: 2),
                        ),
                        filled: true,
                        fillColor: AppColors.surface2,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Select Members to Invite',
                      style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: MediaQuery.of(context).size.height * 0.35,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.borderSubtle),
                        borderRadius: BorderRadius.circular(16),
                        color: AppColors.surface2,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: loadingUsers
                          ? AppShimmer(
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                itemCount: 4,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (_, __) => Row(
                                  children: [
                                    Container(width: 32, height: 32, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                                    const SizedBox(width: 12),
                                    const ShimmerBox(width: 120, height: 14),
                                  ],
                                ),
                              ),
                            )
                          : allUsers.isEmpty
                              ? const Center(child: Text('No users found.'))
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  itemCount: allUsers.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
                                  itemBuilder: (context, idx) {
                                    final u = allUsers[idx];
                                    final uid = u['id'] as String;
                                    final display = u['display_name'] ?? 'User';
                                    final role = u['role'] ?? 'member';
                                    final checked = selectedUserIds.contains(uid);

                                    return CheckboxListTile(
                                      value: checked,
                                      title: Text(display, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                                      subtitle: Text(role.toUpperCase(), style: AppTextStyles.captionSm.copyWith(color: AppColors.textMuted)),
                                      secondary: AppAvatar(
                                        url: u['avatar_url'],
                                        fallbackText: display,
                                        size: 36,
                                      ),
                                      activeColor: AppColors.accent,
                                      checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                      onChanged: (val) {
                                        setWizardState(() {
                                          if (val == true) {
                                            selectedUserIds.add(uid);
                                          } else {
                                            selectedUserIds.remove(uid);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: nameCtrl.text.trim().isEmpty
                              ? null
                              : () async {
                                  Navigator.pop(ctx);
                                  _createGroupWithInvites(
                                    title: nameCtrl.text.trim(),
                                    description: descCtrl.text.trim(),
                                    cardId: selectedCampaignId,
                                    inviteUserIds: selectedUserIds.toList(),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                            ),
                            elevation: 0,
                          ),
                          child: const Text('Create', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _createGroupWithInvites({
    required String title,
    String? description,
    String? cardId,
    required List<String> inviteUserIds,
  }) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      await ChatService().createCustomGroupRoom(
        brandId: user.id,
        title: title,
        description: description,
        cardId: cardId,
        inviteUserIds: inviteUserIds,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Group "$title" created successfully!')),
        );
      }
      _load();
    } catch (e) {
      print('Error creating group room: $e');
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create group chat')),
        );
      }
    }
  }



  void _showRoomOptions(Map<String, dynamic> room) {
    final roomId = room['id'] as String;
    final authNotifier = ref.read(authProvider.notifier);
    final profile = ref.read(authProvider).profile;
    final prefs = Map<String, dynamic>.from(profile?['preferences'] ?? {});

    final List<dynamic> pinned = List<dynamic>.from(prefs['pinned_rooms'] ?? []);
    final List<dynamic> archived = List<dynamic>.from(prefs['archived_rooms'] ?? []);
    final List<dynamic> muted = List<dynamic>.from(prefs['muted_rooms'] ?? []);
    final List<dynamic> unreadOverrides = List<dynamic>.from(prefs['unread_overrides'] ?? []);
    final Map<String, dynamic> clearedRooms = Map<String, dynamic>.from(prefs['cleared_rooms'] ?? {});

    final isPinned = pinned.contains(roomId);
    final isArchived = archived.contains(roomId);
    final isMuted = muted.contains(roomId);
    final isMarkedUnread = unreadOverrides.contains(roomId);

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, color: isPinned ? AppColors.accent : null),
                title: Text(isPinned ? 'Unpin Chat' : 'Pin Chat', style: AppTextStyles.body),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (isPinned) {
                    pinned.remove(roomId);
                  } else {
                    if (pinned.length >= 3) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('You can pin up to 3 chats only!')),
                      );
                      return;
                    }
                    pinned.add(roomId);
                  }
                  prefs['pinned_rooms'] = pinned;
                  await authNotifier.updatePreferences(prefs);
                  _load();
                },
              ),
              ListTile(
                leading: Icon(isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: isMuted ? Colors.orange : null),
                title: Text(isMuted ? 'Unmute Notifications' : 'Mute Notifications', style: AppTextStyles.body),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (isMuted) {
                    muted.remove(roomId);
                  } else {
                    muted.add(roomId);
                  }
                  prefs['muted_rooms'] = muted;
                  await authNotifier.updatePreferences(prefs);
                  _load();
                },
              ),
              ListTile(
                leading: Icon(isArchived ? Icons.unarchive_rounded : Icons.archive_rounded, color: isArchived ? AppColors.accent : null),
                title: Text(isArchived ? 'Unarchive Chat' : 'Archive Chat', style: AppTextStyles.body),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (isArchived) {
                    archived.remove(roomId);
                  } else {
                    archived.add(roomId);
                  }
                  prefs['archived_rooms'] = archived;
                  await authNotifier.updatePreferences(prefs);
                  _load();
                },
              ),
              ListTile(
                leading: Icon(isMarkedUnread ? Icons.mark_chat_read_rounded : Icons.mark_chat_unread_rounded, color: isMarkedUnread ? AppColors.accent : null),
                title: Text(isMarkedUnread ? 'Mark as Read' : 'Mark as Unread', style: AppTextStyles.body),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (isMarkedUnread) {
                    unreadOverrides.remove(roomId);
                  } else {
                    unreadOverrides.add(roomId);
                  }
                  prefs['unread_overrides'] = unreadOverrides;
                  await authNotifier.updatePreferences(prefs);
                  _load();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                title: const Text('Clear History', style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showPremiumConfirmDialog(
                    context: context,
                    title: 'Clear Chat History',
                    message: 'Are you sure you want to clear all messages? This action cannot be undone.',
                    confirmLabel: 'Clear',
                    isDestructive: true,
                    icon: Iconsax.trash,
                  );
                  if (confirm == true) {
                    clearedRooms[roomId] = DateTime.now().toUtc().toIso8601String();
                    prefs['cleared_rooms'] = clearedRooms;
                    await authNotifier.updatePreferences(prefs);
                    _load();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next.user != null && _loading) {
        _load();
        _subscribeToMessages();
      }
    });

    final basePath = widget.role == 'brand' ? '/brand' : '/influencer';
    final searchQuery = _searchCtrl.text.toLowerCase().trim();
    final pinnedRoomIds = ref.watch(pinnedRoomsProvider);
    final archivedRoomIds = ref.watch(archivedRoomsProvider);
    final mutedRoomIds = ref.watch(mutedRoomsProvider);
    final unreadOverrides = ref.watch(unreadOverridesProvider);

    final filteredRooms = _rooms.where((room) {
      final roomId = room['id'] as String;
      final otherUser = widget.role == 'brand'
          ? room['influencer'] as Map<String, dynamic>?
          : room['brand'] as Map<String, dynamic>?;
      final cardTitle = (room['card'] as Map<String, dynamic>?)?['title'] ?? '';
      final displayName = otherUser?['display_name'] ?? '';

      // Search Filter
      final matchesSearch = displayName.toLowerCase().contains(searchQuery) ||
          cardTitle.toLowerCase().contains(searchQuery);
      if (!matchesSearch) return false;

      // Archive behavior
      final isArchived = archivedRoomIds.contains(roomId);
      if (_selectedFilter == 'Archived') {
        if (!isArchived) return false;
      } else {
        if (isArchived) return false;
      }

      // Filter Chips
      if (_selectedFilter == 'Unread') {
        final unreadCount = _unreadCounts[roomId] ?? 0;
        final hasUnread = unreadCount > 0 || unreadOverrides.contains(roomId);
        return hasUnread;
      } else if (_selectedFilter == 'Groups') {
        return room['influencer_id'] == null && room['card_id'] == null;
      } else if (_selectedFilter == 'Campaigns') {
        return room['influencer_id'] == null && room['card_id'] != null;
      }
      return true;
    }).toList();

    // Sort: pinned chats first, then by last message time (most recent first)
    filteredRooms.sort((a, b) {
      final aPinned = pinnedRoomIds.contains(a['id']);
      final bPinned = pinnedRoomIds.contains(b['id']);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;

      // Within same pin group, sort by last message time (newest first)
      final aLastMsg = _lastMessages[a['id']];
      final bLastMsg = _lastMessages[b['id']];
      final aTime = aLastMsg?['created_at'] != null
          ? DateTime.tryParse(aLastMsg!['created_at']) ?? DateTime(2000)
          : DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(2000);
      final bTime = bLastMsg?['created_at'] != null
          ? DateTime.tryParse(bLastMsg!['created_at']) ?? DateTime(2000)
          : DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });

    final unreadNotifications = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56 + AppSpacing.pageMarginVertical),
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.appBarMarginHorizontal,
            right: AppSpacing.appBarMarginHorizontal,
            top: AppSpacing.pageMarginVertical,
          ),
          child: AppBar(
            leading: IconButton(
              icon: const Icon(Iconsax.arrow_left),
              onPressed: () => context.go(widget.role == 'brand' ? '/brand/home' : '/influencer/home'),
            ),
            centerTitle: false,
            titleSpacing: 0,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Messages',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '.',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            actions: [
              if (widget.role == 'brand')
                IconButton(
                  icon: const Icon(Icons.add_rounded, size: 24),
                  onPressed: _showGroupCreationFABOptions,
                ),
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Iconsax.notification, size: 20),
                    onPressed: () => context.push('/${widget.role}/notifications'),
                  ),
                  if (unreadNotifications > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 12,
                          minHeight: 12,
                        ),
                        child: Text(
                          unreadNotifications > 9 ? '9+' : '$unreadNotifications',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(Iconsax.setting_2, size: 20),
                onPressed: () => context.push('/${widget.role}/settings'),
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMarginHorizontal, vertical: 16),
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, __) => const ShimmerChatTile(),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMarginHorizontal),
                child: Column(
                  children: [
                    _buildSearchField(),
                    _buildFilterChips(),
                    Expanded(
                      child: filteredRooms.isEmpty
                          ? const AppEmptyState(
                              icon: Icons.chat_bubble_outline_rounded,
                              title: 'No conversations yet',
                              subtitle: 'Your chats with collaborators will appear here',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.sm,
                                bottom: AppSpacing.bottomScreenPadding + AppSpacing.md,
                              ),
                              itemCount: filteredRooms.length,
                              separatorBuilder: (_, _) => const Divider(height: 1, indent: 64),
                              itemBuilder: (_, i) {
                                final room = filteredRooms[i];
                                final roomId = room['id'] as String;
                                final isGroup = room['influencer_id'] == null;
                                final isPinned = pinnedRoomIds.contains(roomId);

                                final otherUser = widget.role == 'brand'
                                    ? room['influencer'] as Map<String, dynamic>?
                                    : room['brand'] as Map<String, dynamic>?;
                                final cardTitle = (room['card'] as Map<String, dynamic>?)?['title'] ?? '';
                                final lastMsg = _lastMessages[roomId];
                                final unreadCount = _unreadCounts[roomId] ?? 0;
                                final lastTime = lastMsg?['created_at'] != null
                                    ? DateTime.tryParse(lastMsg!['created_at'])
                                    : null;

                                // Online check
                                final lastSeenStr = otherUser?['last_seen'] as String?;
                                bool isOnline = false;
                                if (lastSeenStr != null && !isGroup) {
                                  final lastSeen = DateTime.tryParse(lastSeenStr);
                                  if (lastSeen != null) {
                                    isOnline = DateTime.now().toUtc().difference(lastSeen).inMinutes < 2;
                                  }
                                }

                                final typingName = _typingNames[roomId];

                                final user = ref.read(authProvider).user;
                                if (user != null && room['membership_status'] == 'pending_invite') {
                                  final brandName = room['brand']?['display_name'] ?? 'A Brand';
                                  final groupName = room['title'] ?? (cardTitle.isNotEmpty ? cardTitle : 'Group Chat');
                                  return Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.accent.withOpacity(0.2)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: AppColors.accent.withOpacity(0.1),
                                              child: Icon(Iconsax.notification_bing, color: AppColors.accent, size: 20),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '$brandName invited you to join:',
                                                    style: AppTextStyles.caption.copyWith(
                                                      fontWeight: FontWeight.w600,
                                                      color: AppColors.textSecondary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    groupName,
                                                    style: AppTextStyles.label.copyWith(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            OutlinedButton(
                                              onPressed: () async {
                                                setState(() => _loading = true);
                                                try {
                                                  await ChatService().respondToGroupInvite(roomId, user.id, false);
                                                  _load();
                                                } catch (e) {
                                                  print('Error declining group invite: $e');
                                                  setState(() => _loading = false);
                                                }
                                              },
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppColors.error,
                                                side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              ),
                                              child: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              onPressed: () async {
                                                setState(() => _loading = true);
                                                try {
                                                  await ChatService().respondToGroupInvite(roomId, user.id, true);
                                                  _load();
                                                } catch (e) {
                                                  print('Error accepting group invite: $e');
                                                  setState(() => _loading = false);
                                                }
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.accent,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                elevation: 0,
                                              ),
                                              child: const Text('Accept', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                  return InkWell(
                                    onTap: () async {
                                      await context.push('$basePath/chats/$roomId');
                                      _load();
                                    },
                                    onLongPress: () => _showRoomOptions(room),
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                                    child: Row(
                                      children: [
                                        if (isGroup)
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: AppColors.accent.withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(Icons.group_rounded, color: AppColors.accent, size: 26),
                                          )
                                        else
                                          Stack(
                                            children: [
                                              AppAvatar(
                                                url: otherUser?['avatar_url'],
                                                fallbackText: otherUser?['display_name'] ?? '?',
                                                size: 50,
                                                onTap: () {
                                                  final otherId = otherUser?['id'];
                                                  if (otherId != null) {
                                                    if (widget.role == 'brand') {
                                                      context.push('/brand/influencers/$otherId');
                                                    } else {
                                                      context.push('/influencer/brands/$otherId');
                                                    }
                                                  }
                                                },
                                              ),
                                              if (isOnline)
                                                Positioned(
                                                  right: 0,
                                                  bottom: 0,
                                                  child: Container(
                                                    width: 14,
                                                    height: 14,
                                                    decoration: BoxDecoration(
                                                      color: AppColors.success,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(color: AppColors.surface, width: 2),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Flexible(
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Flexible(
                                                          child: Text(
                                                            isGroup
                                                                ? (room['title'] != null && (room['title'] as String).isNotEmpty
                                                                    ? room['title'] as String
                                                                    : (cardTitle.isNotEmpty ? cardTitle : 'Group Chat'))
                                                                : (otherUser?['display_name'] ?? 'User'),
                                                            style: AppTextStyles.label.copyWith(
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                        if (!isGroup && otherUser?['is_verified'] == true) ...[
                                                          const SizedBox(width: 4),
                                                          const VerificationBadge(size: 14),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                  if (lastTime != null)
                                                    Text(
                                                      timeago.format(lastTime, locale: 'en_short'),
                                                      style: AppTextStyles.captionSm.copyWith(
                                                        fontSize: 10,
                                                        fontWeight: unreadCount > 0
                                                            ? FontWeight.bold
                                                            : FontWeight.normal,
                                                        color: unreadCount > 0
                                                            ? AppColors.accent
                                                            : AppColors.textMuted,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text.rich(
                                                TextSpan(
                                                  children: [
                                                    if (cardTitle.isNotEmpty && !isGroup)
                                                      TextSpan(
                                                        text: 'Re: $cardTitle  •  ',
                                                        style: AppTextStyles.captionSm.copyWith(
                                                          color: AppColors.textMuted,
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.normal,
                                                        ),
                                                      ),
                                                    if (typingName != null)
                                                      TextSpan(
                                                        text: '$typingName is typing...',
                                                        style: AppTextStyles.caption.copyWith(
                                                          color: AppColors.success,
                                                          fontStyle: FontStyle.italic,
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 13,
                                                        ),
                                                      )
                                                    else
                                                      TextSpan(
                                                        text: lastMsg?['content'] ?? 'No messages yet',
                                                        style: AppTextStyles.caption.copyWith(
                                                          fontSize: 13,
                                                          color: unreadCount > 0
                                                              ? AppColors.textPrimary
                                                              : AppColors.textMuted,
                                                          fontWeight: unreadCount > 0
                                                              ? FontWeight.bold
                                                              : FontWeight.normal,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (mutedRoomIds.contains(roomId)) ...[
                                              Icon(
                                                Icons.volume_off_rounded,
                                                size: 16,
                                                color: AppColors.textMuted,
                                              ),
                                              const SizedBox(width: 4),
                                            ],
                                            if (isPinned)
                                              Icon(
                                                Icons.push_pin_rounded,
                                                size: 16,
                                                color: AppColors.accent,
                                              )
                                            else if (unreadCount > 0 || unreadOverrides.contains(roomId))
                                              Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: AppColors.accent,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  unreadCount > 0 ? '$unreadCount' : '',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              )
                                            else
                                              Icon(
                                                Icons.chevron_right_rounded,
                                                size: 20,
                                                color: AppColors.textMuted,
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
            ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (val) => setState(() {}),
        style: AppTextStyles.body,
        decoration: InputDecoration(
          hintText: 'Search chats...',
          hintStyle: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
          suffixIcon: Icon(Icons.tune_rounded, color: AppColors.textMuted, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final unreadOverrides = ref.watch(unreadOverridesProvider);
    final archivedRoomIds = ref.watch(archivedRoomsProvider);

    final totalUnreadChats = _rooms.where((room) {
      final unread = _unreadCounts[room['id']] ?? 0;
      return unread > 0 || unreadOverrides.contains(room['id']);
    }).length;

    final totalGroups = _rooms.where((room) => room['influencer_id'] == null && room['card_id'] == null).length;
    final totalCampaigns = _rooms.where((room) => room['influencer_id'] == null && room['card_id'] != null).length;
    final totalArchived = _rooms.where((room) => archivedRoomIds.contains(room['id'])).length;

    final filters = [
      {'key': 'All', 'label': 'All'},
      {'key': 'Groups', 'label': 'Groups ($totalGroups)'},
      {'key': 'Campaigns', 'label': 'Campaign Chats ($totalCampaigns)'},
      {'key': 'Unread', 'label': 'Unread ($totalUnreadChats)'},
      {'key': 'Archived', 'label': 'Archived ($totalArchived)'},
    ];

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, idx) {
          final filter = filters[idx];
          final key = filter['key']!;
          final label = filter['label']!;
          final selected = _selectedFilter == key;

          return ChoiceChip(
            showCheckmark: false,
            label: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
            selected: selected,
            onSelected: (val) {
              if (val) {
                setState(() {
                  _selectedFilter = key;
                });
              }
            },
            selectedColor: AppColors.surface3,
            backgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: selected ? AppColors.accent : AppColors.border,
                width: 1.5,
              ),
            ),
          );
        },
      ),
    );
  }
}