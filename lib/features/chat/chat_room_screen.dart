import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for Clipboard
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/shared_widgets.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  const ChatRoomScreen({super.key, required this.roomId});

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _room;
  List<Map<String, dynamic>> _milestones = [];
  List<Map<String, dynamic>> _groupMembers = [];
  Map<String, dynamic>? _currentUserMemberInfo;
  bool _loading = true;
  bool _showMilestones = false;
  bool _uploading = false;
  String _uploadingLabel = '';
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  RealtimeChannel? _channel;
  final _chatService = ChatService();

  // Reply and Edit mode
  Map<String, dynamic>? _replyingTo;
  Map<String, dynamic>? _editingMessage;

  // Typing and Online status
  bool _otherUserIsTyping = false;
  DateTime? _otherUserLastSeen;
  Timer? _onlineStatusTimer;
  Timer? _typingTimer;
  bool _isTyping = false;

  bool _showScrollToBottom = false;
  String _otherUserPresence = 'idle'; // 'typing', 'recording', 'uploading', 'idle'

  // Voice recording simulation
  bool _isRecordingVoice = false;
  int _voiceRecordingDuration = 0;
  Timer? _voiceRecordingTimer;
  String? _highlightedMessageId;

  @override
  void initState() {
    super.initState();
    _msgCtrl.addListener(_onTextChanged);
    _scrollCtrl.addListener(() {
      final isUp = _scrollCtrl.hasClients && _scrollCtrl.offset < _scrollCtrl.position.maxScrollExtent - 200;
      if (isUp != _showScrollToBottom) {
        setState(() => _showScrollToBottom = isUp);
      }
    });
    _load();
  }

  List<Map<String, dynamic>> _filterMessages(List<Map<String, dynamic>> rawMsgs) {
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return rawMsgs;

    final profile = ref.read(authProvider).profile;
    final prefs = profile?['preferences'] as Map<String, dynamic>? ?? {};
    final clearedRooms = prefs['cleared_rooms'] as Map<String, dynamic>? ?? {};
    final clearedAtStr = clearedRooms[widget.roomId] as String?;
    final clearedAt = clearedAtStr != null ? DateTime.tryParse(clearedAtStr) : null;

    return rawMsgs.where((msg) {
      // Clear history check
      if (clearedAt != null && msg['created_at'] != null) {
        final createdAt = DateTime.tryParse(msg['created_at']);
        if (createdAt != null && !createdAt.isAfter(clearedAt)) {
          return false;
        }
      }

      // Delete for me check
      final deletedFor = msg['payload']?['deleted_for'] as List<dynamic>?;
      if (deletedFor != null && deletedFor.contains(userId)) {
        return false;
      }

      return true;
    }).toList();
  }

  Future<void> _load() async {
    try {
      // 1. Fetch room and messages in parallel to display them instantly
      final results = await Future.wait([
        _chatService.getRoom(widget.roomId),
        _chatService.getMessages(widget.roomId, limit: 100),
      ]);

      final room = results[0] as Map<String, dynamic>;
      final messages = results[1] as List<Map<String, dynamic>>;

      final user = ref.read(authProvider).user;
      List<Map<String, dynamic>> groupMembers = [];
      Map<String, dynamic>? currentUserMemberInfo;

      if (room['influencer_id'] == null) {
        try {
          groupMembers = await _chatService.getGroupMembers(widget.roomId);
          if (user != null) {
            currentUserMemberInfo = groupMembers.firstWhere(
              (m) => m['user_id'] == user.id,
              orElse: () => <String, dynamic>{},
            );
          }
        } catch (e) {
          print('Error loading group members: $e');
        }
      }

      if (mounted) {
        setState(() {
          _room = room;
          _messages = _filterMessages(messages);
          _groupMembers = groupMembers;
          _currentUserMemberInfo = currentUserMemberInfo;
          _loading = false;
        });
        _scrollToBottom();
      }

      // 2. Load background data asynchronously
      final otherUserId = roleId(room);

      // Run non-critical queries in parallel without blocking initial render
      Future.wait([
        _chatService.getMilestones(widget.roomId).then((milestones) {
          if (mounted) {
            setState(() {
              _milestones = milestones;
            });
          }
        }),
        if (user != null) ...[
          _chatService.markMessagesAsRead(widget.roomId, user.id),
          if (room['influencer_id'] == null) _markAllGroupMessagesAsRead(messages, user.id),
        ],
        if (user != null) _chatService.updateLastSeen(user.id),
        if (otherUserId != null) _chatService.getUserLastSeen(otherUserId).then((lastSeen) {
          if (mounted) {
            setState(() {
              _otherUserLastSeen = lastSeen;
            });
          }
        }),
      ]).catchError((e) {
        print('Error loading background chat room data: $e');
        return <void>[];
      });

      // 3. Subscribe to realtime channels
      if (user != null) {
        try {
          _channel = SupabaseService.client.channel('room:${widget.roomId}');
          _channel!
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'messages',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'room_id',
                  value: widget.roomId,
                ),
                callback: (payload) async {
                  final msgs = await _chatService.getMessages(widget.roomId, limit: 100);
                  await _chatService.markMessagesAsRead(widget.roomId, user.id);
                  if (room['influencer_id'] == null) {
                    await _markAllGroupMessagesAsRead(msgs, user.id);
                  }
                  List<Map<String, dynamic>> updatedMembers = [];
                  if (room['influencer_id'] == null) {
                    updatedMembers = await _chatService.getGroupMembers(widget.roomId);
                  }
                  if (mounted) {
                    setState(() {
                      _messages = _filterMessages(msgs);
                      if (room['influencer_id'] == null) {
                        _groupMembers = updatedMembers;
                        _currentUserMemberInfo = updatedMembers.firstWhere(
                          (m) => m['user_id'] == user.id,
                          orElse: () => <String, dynamic>{},
                        );
                      }
                    });
                    _scrollToBottom();
                  }
                },
              )
              .onBroadcast(
                event: 'typing',
                callback: (payload) {
                  final senderId = payload['senderId'] as String?;
                  final isTyping = payload['isTyping'] as bool?;
                  if (senderId != user.id && mounted) {
                    setState(() {
                      _otherUserIsTyping = isTyping == true;
                    });
                  }
                },
              )
              .onBroadcast(
                event: 'presence',
                callback: (payload) {
                  final senderId = payload['senderId'] as String?;
                  final presenceState = payload['presenceState'] as String?;
                  if (senderId != user.id && mounted) {
                    setState(() {
                      _otherUserPresence = presenceState ?? 'idle';
                    });
                  }
                },
              )
              .subscribe();
        } catch (e) {
          print('Error setting up room channel: $e');
        }
      }

      // Periodic timer to fetch other user's online/last_seen state
      if (otherUserId != null) {
        _onlineStatusTimer?.cancel();
        _onlineStatusTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
          final lastSeen = await _chatService.getUserLastSeen(otherUserId);
          if (mounted) {
            setState(() {
              _otherUserLastSeen = lastSeen;
            });
          }
        });
      }

    } catch (e) {
      print('Error loading chat room: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String? roleId(Map<String, dynamic>? room) {
    final role = ref.read(authProvider).role;
    if (role == 'brand') {
      return room?['influencer_id'] as String?;
    } else {
      return room?['brand_id'] as String?;
    }
  }

  Future<void> _markAllGroupMessagesAsRead(List<Map<String, dynamic>> messages, String userId) async {
    final unread = messages.where((msg) {
      if (msg['sender_id'] == userId) return false;
      final payload = msg['payload'] as Map<String, dynamic>? ?? {};
      final seenBy = payload['seen_by'] as List<dynamic>? ?? [];
      return !seenBy.contains(userId);
    }).toList();

    if (unread.isNotEmpty) {
      try {
        await Future.wait(unread.map((msg) =>
          _chatService.markGroupMessageAsRead(msg['id'], userId, msg['payload'] as Map<String, dynamic>? ?? {})
        ));
      } catch (e) {
        print('Error marking group messages as read: $e');
      }
    }
  }

  void _startSimulatedCall({required bool isVideo}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.95),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) {
        final roomName = _room?['influencer_id'] == null
            ? (_room?['title'] ?? (_room?['card']?['title'] ?? 'Campaign Group'))
            : (ref.read(authProvider).role == 'brand'
                ? (_room?['influencer']?['display_name'] ?? 'Influencer')
                : (_room?['brand']?['display_name'] ?? 'Brand'));
        final avatarUrl = _room?['influencer_id'] == null
            ? null
            : (ref.read(authProvider).role == 'brand'
                ? _room?['influencer']?['avatar_url']
                : _room?['brand']?['avatar_url']);

        return _SimulatedCallScreen(
          roomName: roomName,
          avatarUrl: avatarUrl,
          isVideo: isVideo,
        );
      },
    );
  }

  void _onTextChanged() {
    final hasText = _msgCtrl.text.trim().isNotEmpty;
    if (hasText != _isTyping) {
      _isTyping = hasText;
      _sendPresenceBroadcast(hasText ? 'typing' : 'idle');
    }

    _typingTimer?.cancel();
    if (hasText) {
      _typingTimer = Timer(const Duration(seconds: 2), () {
        if (_isTyping) {
          _isTyping = false;
          _sendPresenceBroadcast('idle');
        }
      });
    }

    setState(() {});
  }

  void _sendPresenceBroadcast(String presenceState) {
    final user = ref.read(authProvider).user;
    final userName = ref.read(authProvider).profile?['display_name'] ?? 'User';
    if (user != null && _channel != null) {
      try {
        _channel!.sendBroadcastMessage(
          event: 'presence',
          payload: {
            'senderId': user.id,
            'senderName': userName,
            'presenceState': presenceState,
          },
        );
      } catch (e) {
        print('Error sending presence broadcast: $e');
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(authProvider).user;
    if (user == null) return;

    _msgCtrl.clear();
    _isTyping = false;
    _sendPresenceBroadcast('idle');

    // If in edit mode, update message instead of sending new
    if (_editingMessage != null) {
      final messageId = _editingMessage!['id'] as String;
      final payload = _editingMessage!['payload'] ?? {};
      setState(() => _editingMessage = null);
      try {
        await _chatService.editMessage(messageId, text, payload);
        final msgs = await _chatService.getMessages(widget.roomId, limit: 100);
        if (mounted) {
          setState(() => _messages = msgs);
          _scrollToBottom();
        }
      } catch (e) {
        print('Error editing message: $e');
      }
      return;
    }

    Map<String, dynamic>? payload;
    if (_replyingTo != null) {
      final senderName = _replyingTo!['sender']?['display_name'] ?? 'User';
      payload = {
        'quoted_id': _replyingTo!['id'],
        'quoted_sender': senderName,
        'quoted_content': _replyingTo!['content'] ?? 'Photo',
      };
    }

    try {
      await _chatService.updateLastSeen(user.id);
      await _chatService.sendMessage(
        roomId: widget.roomId,
        senderId: user.id,
        content: text,
        payload: payload,
      );

      if (mounted) {
        setState(() {
          _replyingTo = null;
        });
      }

      final msgs = await _chatService.getMessages(widget.roomId, limit: 100);
      if (mounted) {
        setState(() => _messages = msgs);
        _scrollToBottom();
      }
    } catch (e) {
      print('Error sending message: $e');
    }
  }



  void _startVoiceRecording() {
    setState(() {
      _isRecordingVoice = true;
      _voiceRecordingDuration = 0;
    });
    _sendPresenceBroadcast('recording');
    _voiceRecordingTimer?.cancel();
    _voiceRecordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _voiceRecordingDuration++;
        });
      }
    });
  }

  void _cancelVoiceRecording() {
    _voiceRecordingTimer?.cancel();
    setState(() {
      _isRecordingVoice = false;
      _voiceRecordingDuration = 0;
    });
    _sendPresenceBroadcast('idle');
  }

  Future<void> _sendVoiceRecording() async {
    final duration = _voiceRecordingDuration;
    _voiceRecordingTimer?.cancel();
    setState(() {
      _isRecordingVoice = false;
      _voiceRecordingDuration = 0;
      _uploading = true;
      _uploadingLabel = 'Sending voice note...';
    });
    _sendPresenceBroadcast('uploading');

    // Simulate short network delay
    await Future.delayed(const Duration(milliseconds: 1200));

    final user = ref.read(authProvider).user;
    if (user != null) {
      try {
        await _chatService.sendMessage(
          roomId: widget.roomId,
          senderId: user.id,
          content: 'Voice note (${duration}s)',
          attachmentUrl: 'mock://voice-note-${DateTime.now().millisecondsSinceEpoch}.mp3',
          attachmentType: 'audio',
          payload: {
            'duration': duration,
          },
        );
        final msgs = await _chatService.getMessages(widget.roomId, limit: 100);
        if (mounted) {
          setState(() {
            _messages = msgs;
          });
          _scrollToBottom();
        }
      } catch (e) {
        print('Error sending voice note: $e');
      }
    }

    if (mounted) {
      setState(() {
        _uploading = false;
        _uploadingLabel = '';
      });
    }
    _sendPresenceBroadcast('idle');
  }

  Future<void> _togglePinMessage(String messageId, bool isPinned, Map<String, dynamic> payload) async {
    try {
      await _chatService.pinMessage(messageId, payload, isPinned);
      final msgs = await _chatService.getMessages(widget.roomId, limit: 100);
      if (mounted) {
        setState(() {
          _messages = msgs;
        });
      }
    } catch (e) {
      print('Error pinning message: $e');
    }
  }

  Future<void> _deleteMessageForMe(String messageId, Map<String, dynamic> payload) async {
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;
    try {
      await _chatService.deleteMessageForMe(messageId, userId, payload);
      final msgs = await _chatService.getMessages(widget.roomId, limit: 100);
      if (mounted) {
        setState(() {
          _messages = _filterMessages(msgs);
        });
      }
    } catch (e) {
      print('Error deleting message for me: $e');
    }
  }

  Future<void> _deleteMessageForEveryone(String messageId, Map<String, dynamic> payload) async {
    try {
      await _chatService.deleteMessageForEveryone(messageId, payload);
      final msgs = await _chatService.getMessages(widget.roomId, limit: 100);
      if (mounted) {
        setState(() {
          _messages = msgs;
        });
      }
    } catch (e) {
      print('Error deleting message for everyone: $e');
    }
  }

  Future<void> _forwardMessageDialog(Map<String, dynamic> msg) async {
    final user = ref.read(authProvider).user;
    final role = ref.read(authProvider).role;
    if (user == null || role == null) return;

    final rooms = await _chatService.getRooms(user.id, role);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Forward Message'),
          content: rooms.isEmpty
              ? const Text('No chats to forward to.')
              : SizedBox(
                  width: double.maxFinite,
                  height: 300,
                  child: ListView.builder(
                    itemCount: rooms.length,
                    itemBuilder: (context, idx) {
                      final room = rooms[idx];
                      final isGroup = room['influencer_id'] == null;
                      final title = isGroup
                          ? (room['card']?['title'] ?? 'Group')
                          : ((role == 'brand' ? room['influencer'] : room['brand'])?['display_name'] as String?) ?? 'User';

                      return ListTile(
                        leading: isGroup
                            ? Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.group_rounded, color: AppColors.accent, size: 20),
                              )
                            : AppAvatar(
                                url: (role == 'brand' ? room['influencer'] : room['brand'])?['avatar_url'] as String?,
                                fallbackText: title,
                                size: 36,
                              ),
                        title: Text(title, style: AppTextStyles.body),
                        onTap: () async {
                          Navigator.pop(ctx);
                          try {
                            await _chatService.forwardMessage(
                              targetRoomId: room['id'] as String,
                              senderId: user.id,
                              content: msg['content'] ?? '',
                              attachmentUrl: msg['attachment_url'] as String?,
                              attachmentType: msg['attachment_type'] as String?,
                              forwardedFrom: ref.read(authProvider).profile?['display_name'] ?? 'User',
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Message forwarded to $title')),
                            );
                          } catch (e) {
                            print('Error forwarding message: $e');
                          }
                        },
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _openImageViewer(String selectedUrl) {
    final imageMsgs = _messages.where((m) => m['attachment_type'] == 'image' && m['attachment_url'] != null).toList();
    final urls = imageMsgs.map((m) => m['attachment_url'] as String).toList();
    final initialIndex = urls.indexOf(selectedUrl);
    
    context.push(
      '/image-viewer',
      extra: {
        'urls': urls,
        'initialIndex': initialIndex >= 0 ? initialIndex : 0,
        'title': _room?['card']?['title'] ?? 'Chat Photos',
      },
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await url_launcher.canLaunchUrl(uri)) {
      await url_launcher.launchUrl(uri, mode: url_launcher.LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open link: $url')),
      );
    }
  }

  Future<void> _downloadFile(String url, String fileName) async {
    await Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('File link copied to clipboard: $fileName'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => _launchURL(url),
        ),
      ),
    );
  }

  void _showSharedMediaGallery() {
    final imageMsgs = _messages.where((m) => m['attachment_type'] == 'image' && m['attachment_url'] != null).toList();
    final fileMsgs = _messages.where((m) => (m['attachment_type'] == 'file' || m['attachment_type'] == 'document' || m['attachment_type'] == 'audio') && m['attachment_url'] != null).toList();
    
    final linkRegExp = RegExp(r'https?://[^\s]+');
    final linkMsgs = _messages.where((m) {
      final content = m['content'] as String? ?? '';
      return linkRegExp.hasMatch(content);
    }).toList();

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DefaultTabController(
          length: 3,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.borderSubtle,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Shared Media', style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TabBar(
                  labelColor: AppColors.accent,
                  unselectedLabelColor: AppColors.textMuted,
                  indicatorColor: AppColors.accent,
                  tabs: [
                    Tab(text: 'Photos (${imageMsgs.length})'),
                    Tab(text: 'Files (${fileMsgs.length})'),
                    Tab(text: 'Links (${linkMsgs.length})'),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Photos Grid
                      imageMsgs.isEmpty
                          ? Center(child: Text('No shared photos', style: AppTextStyles.caption))
                          : GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: imageMsgs.length,
                              itemBuilder: (context, idx) {
                                final msg = imageMsgs[idx];
                                final url = msg['attachment_url'] as String;
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _openImageViewer(url);
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(url, fit: BoxFit.cover),
                                  ),
                                );
                              },
                            ),

                      // Files List
                      fileMsgs.isEmpty
                          ? Center(child: Text('No shared files', style: AppTextStyles.caption))
                          : ListView.builder(
                              itemCount: fileMsgs.length,
                              itemBuilder: (context, idx) {
                                final msg = fileMsgs[idx];
                                final url = msg['attachment_url'] as String;
                                final name = msg['content'] ?? 'Attachment';
                                final type = msg['attachment_type'] ?? 'file';
                                IconData icon = Icons.insert_drive_file_rounded;
                                if (type == 'audio') icon = Icons.headset_rounded;
                                return ListTile(
                                  leading: Icon(icon, color: AppColors.accent),
                                  title: Text(name, style: AppTextStyles.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(type.toUpperCase(), style: AppTextStyles.captionSm),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.download_rounded),
                                    onPressed: () => _downloadFile(url, name),
                                  ),
                                  onTap: () => _launchURL(url),
                                );
                              },
                            ),

                      // Links List
                      linkMsgs.isEmpty
                          ? Center(child: Text('No shared links', style: AppTextStyles.caption))
                          : ListView.builder(
                              itemCount: linkMsgs.length,
                              itemBuilder: (context, idx) {
                                final msg = linkMsgs[idx];
                                final content = msg['content'] as String? ?? '';
                                final match = linkRegExp.firstMatch(content);
                                final url = match?.group(0) ?? '';
                                return ListTile(
                                  leading: const Icon(Icons.link_rounded, color: Colors.blue),
                                  title: Text(url, style: AppTextStyles.body.copyWith(color: Colors.blue, decoration: TextDecoration.underline), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(content, style: AppTextStyles.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                                  onTap: () => _launchURL(url),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _clearChatHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Clear Chat'),
        content: const Text('Are you sure you want to clear your message history for this chat? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final authState = ref.read(authProvider);
      final profile = authState.profile;
      if (profile != null) {
        final prefs = Map<String, dynamic>.from(profile['preferences'] as Map<String, dynamic>? ?? {});
        final clearedRooms = Map<String, dynamic>.from(prefs['cleared_rooms'] as Map<String, dynamic>? ?? {});
        clearedRooms[widget.roomId] = DateTime.now().toUtc().toIso8601String();
        prefs['cleared_rooms'] = clearedRooms;

        try {
          await ref.read(authProvider.notifier).updatePreferences(prefs);
          if (mounted) {
            setState(() {
              _messages = _filterMessages(_messages);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Chat history cleared')),
            );
          }
        } catch (e) {
          print('Error clearing chat history: $e');
        }
      }
    }
  }

  @override
  void dispose() {
    _msgCtrl.removeListener(_onTextChanged);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _typingTimer?.cancel();
    _onlineStatusTimer?.cancel();
    _voiceRecordingTimer?.cancel();
    if (_channel != null) {
      try {
        SupabaseService.client.removeChannel(_channel!);
      } catch (e) {
        print('Error removing channel on dispose: $e');
      }
    }
    super.dispose();
  }

  List<dynamic> _buildMessageItemsList() {
    final items = <dynamic>[];
    if (_messages.isEmpty) return items;

    DateTime? lastDate;
    for (final msg in _messages) {
      final createdAtStr = msg['created_at'] as String?;
      if (createdAtStr != null) {
        final msgDate = DateTime.parse(createdAtStr).toLocal();
        final dayDate = DateTime(msgDate.year, msgDate.month, msgDate.day);

        if (lastDate == null || dayDate != lastDate) {
          items.add(dayDate);
          lastDate = dayDate;
        }
      }
      items.add(msg);
    }
    return items;
  }

  Widget _buildUploadingPlaceholder() {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(top: 8, left: 64),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.12),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                _uploadingLabel,
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) {
      return 'TODAY';
    } else if (date == yesterday) {
      return 'YESTERDAY';
    } else {
      return DateFormat('MMMM d, yyyy').format(date);
    }
  }

  Widget _buildPinnedMessageBanner() {
    final pinnedMsg = _messages.firstWhere(
      (m) => m['payload']?['is_pinned'] == true,
      orElse: () => {},
    );
    if (pinnedMsg.isEmpty) return const SizedBox.shrink();

    final senderName = pinnedMsg['sender_id'] == ref.read(authProvider).user?.id
        ? 'You'
        : (pinnedMsg['sender']?['display_name'] ?? 'User');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          Icon(Icons.pin_drop_rounded, size: 20, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () {
                final idx = _messages.indexWhere((m) => m['id'] == pinnedMsg['id']);
                if (idx != -1) {
                  final offset = idx * 80.0;
                  if (_scrollCtrl.hasClients) {
                    final target = offset.clamp(0.0, _scrollCtrl.position.maxScrollExtent);
                    _scrollCtrl.animateTo(
                      target,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  }
                  setState(() {
                    _highlightedMessageId = pinnedMsg['id'] as String;
                  });
                  Timer(const Duration(seconds: 2), () {
                    if (mounted) {
                      setState(() {
                        _highlightedMessageId = null;
                      });
                    }
                  });
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pinned Message',
                    style: AppTextStyles.label.copyWith(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$senderName: ${pinnedMsg['content'] ?? 'Shared a file'}',
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () {
              _togglePinMessage(pinnedMsg['id'] as String, false, pinnedMsg['payload'] as Map<String, dynamic>? ?? {});
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authProvider).user?.id;
    final role = ref.watch(authProvider).role ?? 'brand';
    final dynamic otherUserRaw = role == 'brand' ? (_room?['influencer']) : (_room?['brand']);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    final otherUserMap = otherUserRaw is Map<String, dynamic> ? otherUserRaw : null;
    final isGroup = _room?['influencer_id'] == null;
    final isOwner = _currentUserMemberInfo?['role'] == 'owner' || _room?['brand_id'] == userId;
    final isGroupAdmin = _currentUserMemberInfo?['role'] == 'admin' || isOwner;
    final isOnlyAdminCanMessage = isGroup && _room?['status'] == 'group_admin_only';

    // Muted check
    final mutedUntilStr = _currentUserMemberInfo?['muted_until'] as String?;
    final isMuted = mutedUntilStr != null && DateTime.tryParse(mutedUntilStr)?.isAfter(DateTime.now()) == true;

    // Online calculation
    bool isOnline = false;
    if (_otherUserLastSeen != null && !isGroup) {
      isOnline = DateTime.now().toUtc().difference(_otherUserLastSeen!).inMinutes < 2;
    }

    String statusText = 'Offline';
    if (isGroup) {
      statusText = 'Tap for details';
    } else if (_otherUserIsTyping || _otherUserPresence == 'typing') {
      statusText = 'Typing...';
    } else if (_otherUserPresence == 'recording') {
      statusText = 'Recording audio...';
    } else if (_otherUserPresence == 'uploading') {
      statusText = 'Uploading media...';
    } else if (isOnline) {
      statusText = 'Online';
    } else if (_otherUserLastSeen != null) {
      statusText = 'Last seen ${timeago.format(_otherUserLastSeen!)}';
    }

    final items = _buildMessageItemsList();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: isGroup
              ? _showGroupInfoPanel
              : () {
                  final otherId = otherUserMap?['id'];
                  if (otherId != null) {
                    if (role == 'brand') {
                      context.push('/brand/influencers/$otherId');
                    } else {
                      context.push('/influencer/brands/$otherId');
                    }
                  }
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                if (isGroup)
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.group_rounded, color: AppColors.accent, size: 20),
                  )
                else
                  Stack(
                    children: [
                      AppAvatar(
                        url: otherUserMap?['avatar_url'],
                        fallbackText: otherUserMap?['display_name'] ?? '?',
                        size: 36,
                        onTap: () {
                          final otherId = otherUserMap?['id'];
                          if (otherId != null) {
                            if (role == 'brand') {
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
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.surface, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              isGroup
                                  ? (_room?['card']?['title'] ?? 'Campaign Group')
                                  : (otherUserMap?['display_name'] ?? ''),
                              style: AppTextStyles.label.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isGroup && otherUserMap?['is_verified'] == true) ...[
                            const SizedBox(width: 4),
                            const VerificationBadge(size: 14),
                          ],
                        ],
                      ),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: !isGroup && (_otherUserIsTyping || _otherUserPresence == 'typing' || _otherUserPresence == 'recording' || _otherUserPresence == 'uploading' || isOnline) ? AppColors.success : AppColors.textMuted,
                          fontWeight: !isGroup && (_otherUserIsTyping || _otherUserPresence == 'typing' || _otherUserPresence == 'recording' || _otherUserPresence == 'uploading' || isOnline) ? FontWeight.w600 : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (!isGroup) ...[
            IconButton(
              icon: const Icon(Icons.call_rounded, size: 20),
              onPressed: () => _startSimulatedCall(isVideo: false),
            ),
            IconButton(
              icon: const Icon(Icons.videocam_rounded, size: 20),
              onPressed: () => _startSimulatedCall(isVideo: true),
            ),
          ],
          IconButton(
            icon: Icon(_showMilestones ? Icons.chat_bubble_rounded : Icons.flag_rounded, size: 22),
            onPressed: () => setState(() => _showMilestones = !_showMilestones),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            color: AppColors.surface,
            onSelected: (val) {
              if (val == 'info') {
                if (isGroup) {
                  _showGroupInfoPanel();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chat Info - Coming Soon!')),
                  );
                }
              } else if (val == 'starred') {
                _showStarredMessages();
              } else if (val == 'media') {
                _showSharedMediaGallery();
              } else if (val == 'clear') {
                _clearChatHistory();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(value: 'info', child: Text(isGroup ? 'Group Info' : 'View Info')),
              const PopupMenuItem(value: 'media', child: Text('Shared Media')),
              const PopupMenuItem(value: 'starred', child: Text('Starred Messages')),
              const PopupMenuItem(value: 'clear', child: Text('Clear Chat')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPinnedMessageBanner(),
          // Milestones panel
          if (_showMilestones)
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Milestones', style: AppTextStyles.label),
                      TextButton.icon(
                        onPressed: _addMilestone,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  if (_milestones.isEmpty)
                    Padding(padding: const EdgeInsets.all(8), child: Text('No milestones set', style: AppTextStyles.captionSm))
                  else
                    ...List.generate(_milestones.length, (i) {
                      final m = _milestones[i];
                      final done = m['status'] == 'completed';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => _toggleMilestone(m),
                              child: Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 20, color: done ? AppColors.success : AppColors.textMuted),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(m['title'] ?? '', style: AppTextStyles.bodySm.copyWith(decoration: done ? TextDecoration.lineThrough : null))),
                          ],
                        ),
                      );
                    }),
                  const Divider(),
                ],
              ),
            ),

          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: items.length + (_uploading ? 1 : 0),
              itemBuilder: (_, i) {
                // Show uploading placeholder as the last item
                if (_uploading && i == items.length) {
                  return _buildUploadingPlaceholder();
                }

                final item = items[i];
                if (item is DateTime) {
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Text(
                        _formatDateHeader(item),
                        style: AppTextStyles.captionSm.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  );
                }

                final msg = item as Map<String, dynamic>;
                final isMe = msg['sender_id'] == userId;
                final time = msg['created_at'] != null
                    ? DateFormat('h:mm a').format(DateTime.parse(msg['created_at']).toLocal())
                    : '';

                final bubble = _buildMessageBubble(msg, isMe, time);

                return Dismissible(
                  key: Key('msg_${msg['id']}'),
                  direction: DismissDirection.startToEnd,
                  confirmDismiss: (direction) async {
                    setState(() {
                      _replyingTo = msg;
                      _editingMessage = null;
                    });
                    return false;
                  },
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 16),
                    color: Colors.transparent,
                    child: Icon(Icons.reply_rounded, color: AppColors.accent),
                  ),
                  child: bubble,
                );
              },
            ),
          ),

          // Bottom Bar
          if (isGroup && (isOnlyAdminCanMessage && !isGroupAdmin))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                border: Border(top: BorderSide(color: AppColors.borderSubtle)),
              ),
              child: Center(
                child: Text(
                  'Only admins can send messages to this group.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else if (isGroup && isMuted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                border: Border(top: BorderSide(color: AppColors.borderSubtle)),
              ),
              child: Center(
                child: Text(
                  'You have been muted in this group.',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.redAccent,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else
            Container(
              color: AppColors.surface,
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                MediaQuery.of(context).viewInsets.bottom > 0
                    ? AppSpacing.sm
                    : MediaQuery.of(context).padding.bottom + AppSpacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildReplyPreview(),
                  _buildEditingPreview(),
                  const SizedBox(height: 4),
                  _isRecordingVoice
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.fiber_manual_record, color: Colors.red, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                '${_voiceRecordingDuration ~/ 60}:${(_voiceRecordingDuration % 60).toString().padLeft(2, '0')}',
                                style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Recording voice...',
                                  style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic),
                                ),
                              ),
                              TextButton(
                                onPressed: _cancelVoiceRecording,
                                child: const Text('Cancel', style: TextStyle(color: Colors.red)),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _sendVoiceRecording,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check, color: Colors.white, size: 20),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface2,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: AppColors.borderSubtle),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.sentiment_satisfied_alt_rounded, color: AppColors.textMuted),
                                      onPressed: () {},
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: _msgCtrl,
                                        style: AppTextStyles.body,
                                        keyboardType: TextInputType.multiline,
                                        maxLines: null,
                                        decoration: InputDecoration(
                                          hintText: 'Message',
                                          hintStyle: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                                          border: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          errorBorder: InputBorder.none,
                                          disabledBorder: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: _showFilePicker,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.surface2,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.borderSubtle),
                                ),
                                child: Icon(
                                  Icons.camera_alt_rounded,
                                  size: 20,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: _msgCtrl.text.trim().isNotEmpty ? _send : _startVoiceRecording,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _msgCtrl.text.trim().isNotEmpty ? Icons.send_rounded : Icons.mic_rounded,
                                  size: 22,
                                  color: AppColors.accentOnDark,
                                ),
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
  }

  Widget _buildReplyPreview() {
    if (_replyingTo == null) return const SizedBox.shrink();
    final senderName = _replyingTo!['sender_id'] == ref.read(authProvider).user?.id
        ? 'You'
        : (_replyingTo!['sender']?['display_name'] ?? 'User');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        senderName,
                        style: AppTextStyles.label.copyWith(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_replyingTo!['sender']?['is_verified'] == true && _replyingTo!['sender_id'] != ref.read(authProvider).user?.id) ...[
                      const SizedBox(width: 4),
                      const VerificationBadge(size: 12),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _replyingTo!['content'] ?? 'Photo',
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }

  Widget _buildEditingPreview() {
    if (_editingMessage == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Editing Message',
                  style: AppTextStyles.label.copyWith(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  _editingMessage!['content'] ?? '',
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () {
              setState(() {
                _editingMessage = null;
                _msgCtrl.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuotedMessage(Map<String, dynamic> msg, bool isMe) {
    final payload = msg['payload'];
    if (payload == null || payload['quoted_content'] == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: (isMe ? Colors.white : AppColors.surface).withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: isMe ? Colors.white : AppColors.accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            payload['quoted_sender'] ?? 'User',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: isMe ? Colors.white : AppColors.accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            payload['quoted_content'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: isMe ? Colors.white.withOpacity(0.9) : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageAttachment(Map<String, dynamic> msg) {
    final url = msg['attachment_url'] as String?;
    final type = msg['attachment_type'] as String?;

    if (url == null && type == null) return const SizedBox.shrink();

    if (type == 'image' && url != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: GestureDetector(
          onTap: () => _openImageViewer(url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              height: 160,
              width: double.infinity,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  height: 160,
                  color: AppColors.surface2,
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              },
            ),
          ),
        ),
      );
    }

    if (type == 'audio' && url != null) {
      final isMe = msg['sender_id'] == ref.read(authProvider).user?.id;
      final duration = msg['payload']?['duration'] as int? ?? 0;
      return VoiceNotePlayerWidget(
        url: url,
        duration: duration,
        isMe: isMe,
      );
    }

    IconData icon = Icons.insert_drive_file_rounded;
    Color iconColor = Colors.purple;

    if (type == 'location') {
      icon = Icons.location_on_rounded;
      iconColor = Colors.green;
    } else if (type == 'contact') {
      icon = Icons.person_rounded;
      iconColor = Colors.blue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () {
                if (url != null) _launchURL(url);
              },
              child: Text(
                msg['content'] ?? 'Attachment',
                style: AppTextStyles.bodySm.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: url != null ? TextDecoration.underline : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionBadges(Map<String, dynamic> msg) {
    final reactions = msg['payload']?['reactions'] as Map<String, dynamic>?;
    if (reactions == null || reactions.isEmpty) return const SizedBox.shrink();

    final Map<String, int> emojiCounts = {};
    reactions.forEach((uid, emoji) {
      emojiCounts[emoji] = (emojiCounts[emoji] ?? 0) + 1;
    });

    final userId = ref.read(authProvider).user?.id;

    return Align(
      alignment: Alignment.bottomLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: emojiCounts.entries.map((entry) {
            final emoji = entry.key;
            final count = entry.value;
            final hasReacted = reactions[userId] == emoji;

            return GestureDetector(
              onTap: () {
                _reactToMessage(msg['id'] as String, emoji, msg['payload'] as Map<String, dynamic>? ?? {});
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: hasReacted ? AppColors.accent.withOpacity(0.15) : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: hasReacted ? AppColors.accent : AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 11)),
                    if (count > 1) ...[
                      const SizedBox(width: 2),
                      Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: hasReacted ? AppColors.accent : AppColors.textMuted)),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe, String time) {
    final senderName = msg['sender']?['display_name'] ?? 'User';
    final isEdited = msg['payload']?['is_edited'] == true;
    final userId = ref.read(authProvider).user?.id;
    final isStarred = (msg['payload']?['starred_by'] as List<dynamic>?)?.contains(userId) ?? false;
    final isHighlighted = _highlightedMessageId == msg['id'];

    return GestureDetector(
      onDoubleTap: () {
        setState(() {
          _replyingTo = msg;
          _editingMessage = null;
        });
      },
      onLongPress: () => _showMessageOptions(msg),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isMe ? AppColors.accent : AppColors.surface2,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: isHighlighted
                    ? Border.all(color: Colors.amber, width: 2)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0, left: 4.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              senderName,
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (msg['sender']?['is_verified'] == true) ...[
                            const SizedBox(width: 4),
                            const VerificationBadge(size: 11),
                          ],
                        ],
                      ),
                    ),

                  _buildQuotedMessage(msg, isMe),
                  _buildMessageAttachment(msg),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      msg['content'] ?? '',
                      style: AppTextStyles.body.copyWith(
                        color: isMe ? AppColors.accentOnDark : AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ),

                  _buildReactionBadges(msg),

                  const SizedBox(height: 4),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Spacer(),
                      if (isStarred) ...[
                        const Icon(Icons.star_rounded, size: 11, color: Colors.amber),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        '${isEdited ? 'Edited • ' : ''}$time',
                        style: TextStyle(
                          fontSize: 9,
                          color: isMe ? AppColors.accentOnDark.withOpacity(0.7) : AppColors.textMuted,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all_rounded,
                          size: 14,
                          color: msg['is_read'] == true ? const Color(0xFF34B7F1) : Colors.white60,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMessageOptions(Map<String, dynamic> msg) {
    final userId = ref.read(authProvider).user?.id;
    final isMyMessage = msg['sender_id'] == userId;
    final isStarred = (msg['payload']?['starred_by'] as List<dynamic>?)?.contains(userId) ?? false;
    final isPinned = msg['payload']?['is_pinned'] == true;

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Reactions row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['👍', '❤️', '😂', '🔥', '😮', '😢'].map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _reactToMessage(msg['id'] as String, emoji, msg['payload'] as Map<String, dynamic>? ?? {});
                      },
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    );
                  }).toList(),
                ),
                const Divider(height: 24),
                ListTile(
                  leading: Icon(isStarred ? Icons.star_rounded : Icons.star_border_rounded, color: isStarred ? Colors.amber : null),
                  title: Text(isStarred ? 'Unstar Message' : 'Star Message', style: AppTextStyles.body),
                  onTap: () {
                    Navigator.pop(ctx);
                    _toggleStarMessage(msg['id'] as String, !isStarred, msg['payload'] as Map<String, dynamic>? ?? {});
                  },
                ),
                if (_room?['influencer_id'] == null) ...[
                  ListTile(
                    leading: const Icon(Icons.remove_red_eye_rounded),
                    title: Text('Seen By', style: AppTextStyles.body),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showSeenByDialog(msg);
                    },
                  ),
                ],
                ListTile(
                  leading: const Icon(Icons.reply_rounded),
                  title: Text('Reply', style: AppTextStyles.body),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _replyingTo = msg;
                      _editingMessage = null;
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.content_copy_rounded),
                  title: Text('Copy Message', style: AppTextStyles.body),
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: msg['content'] ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.forward_rounded),
                  title: Text('Forward Message', style: AppTextStyles.body),
                  onTap: () {
                    Navigator.pop(ctx);
                    _forwardMessageDialog(msg);
                  },
                ),
                ListTile(
                  leading: Icon(isPinned ? Icons.pin_drop_outlined : Icons.pin_drop_rounded),
                  title: Text(isPinned ? 'Unpin Message' : 'Pin Message', style: AppTextStyles.body),
                  onTap: () {
                    Navigator.pop(ctx);
                    _togglePinMessage(msg['id'] as String, !isPinned, msg['payload'] as Map<String, dynamic>? ?? {});
                  },
                ),
                if (isMyMessage) ...[
                  ListTile(
                    leading: const Icon(Icons.edit_rounded),
                    title: Text('Edit Message', style: AppTextStyles.body),
                    onTap: () {
                      Navigator.pop(ctx);
                      _startEditingMessage(msg);
                    },
                  ),
                ],
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  title: const Text('Delete for Me', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _deleteMessageForMe(msg['id'] as String, msg['payload'] as Map<String, dynamic>? ?? {});
                  },
                ),
                if (isMyMessage) ...[
                  ListTile(
                    leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                    title: const Text('Delete for Everyone', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _deleteMessageForEveryone(msg['id'] as String, msg['payload'] as Map<String, dynamic>? ?? {});
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSeenByDialog(Map<String, dynamic> msg) {
    final seenByList = List<String>.from(msg['payload']?['seen_by'] ?? []);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Seen By'),
          content: seenByList.isEmpty
              ? const SizedBox(
                  height: 100,
                  child: Center(child: Text('No one has read this message yet.')),
                )
              : SizedBox(
                  width: double.maxFinite,
                  height: 250,
                  child: ListView.builder(
                    itemCount: seenByList.length,
                    itemBuilder: (context, idx) {
                      final uid = seenByList[idx];
                      final member = _groupMembers.firstWhere(
                        (m) => m['user_id'] == uid,
                        orElse: () => <String, dynamic>{},
                      );
                      
                      final profile = member['profiles'] as Map<String, dynamic>? ?? {};
                      final name = profile['display_name'] ?? 'User';
                      final roleText = member['role'] ?? 'member';

                      return ListTile(
                        leading: AppAvatar(
                          url: profile['avatar_url'],
                          fallbackText: name,
                          size: 32,
                        ),
                        title: Text(name, style: AppTextStyles.body),
                        subtitle: Text(roleText.toUpperCase(), style: AppTextStyles.captionSm),
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _startEditingMessage(Map<String, dynamic> msg) {
    setState(() {
      _editingMessage = msg;
      _replyingTo = null;
      _msgCtrl.text = msg['content'] ?? '';
    });
  }

  Future<void> _reactToMessage(String messageId, String emoji, Map<String, dynamic> payload) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    try {
      final reactions = payload['reactions'] as Map<String, dynamic>? ?? {};
      final existingReaction = reactions[user.id];
      if (existingReaction == emoji) {
        final newPayload = Map<String, dynamic>.from(payload);
        final Map<String, dynamic> newReactions = Map<String, dynamic>.from(newPayload['reactions'] ?? {});
        newReactions.remove(user.id);
        newPayload['reactions'] = newReactions;
        await SupabaseService.client.from('messages').update({
          'payload': newPayload,
        }).eq('id', messageId);
      } else {
        await _chatService.addReaction(messageId, user.id, emoji, payload);
      }
      final msgs = await _chatService.getMessages(widget.roomId, limit: 100);
      if (mounted) setState(() => _messages = msgs);
    } catch (e) {
      print('Error reacting to message: $e');
    }
  }

  Future<void> _toggleStarMessage(String messageId, bool isStarred, Map<String, dynamic> payload) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    try {
      await _chatService.starMessage(messageId, user.id, payload, isStarred);
      final msgs = await _chatService.getMessages(widget.roomId, limit: 100);
      if (mounted) setState(() => _messages = msgs);
    } catch (e) {
      print('Error starring message: $e');
    }
  }

  Future<void> _showGroupInfoPanel() async {
    if (_room == null) return;
    
    final userId = ref.read(authProvider).user?.id;

    // Retrieve info from _room
    final brandName = _room!['brand']?['display_name'] ?? 'Brand Admin';
    final cardTitle = _room!['card']?['title'] ?? '';
    final roomTitle = _room!['title'] ?? (cardTitle.isNotEmpty ? cardTitle : 'Group Chat');
    final roomDesc = _room!['description'] ?? 'Collaborate on deliverables, milestones, and payments.';
    
    // Find current user's role in the group
    final currentUserRole = _currentUserMemberInfo?['role'] as String? ?? 'member';
    final isCurrentUserOwner = currentUserRole == 'owner' || _room!['brand_id'] == userId;
    final isCurrentUserAdmin = currentUserRole == 'admin' || isCurrentUserOwner;

    // Filter shared media files from messages
    final imageMsgs = _messages.where((m) => m['attachment_type'] == 'image' && m['attachment_url'] != null).toList();
    final fileMsgs = _messages.where((m) => (m['attachment_type'] == 'file' || m['attachment_type'] == 'document') && m['attachment_url'] != null).toList();
    final voiceMsgs = _messages.where((m) => (m['attachment_type'] == 'audio') && m['attachment_url'] != null).toList();
    
    final linkRegExp = RegExp(r'https?://[^\s]+');
    final linkMsgs = _messages.where((m) {
      final content = m['content'] as String? ?? '';
      return linkRegExp.hasMatch(content);
    }).toList();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DefaultTabController(
          length: 3,
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              // Fetch latest status dynamically from _room (loaded/synced)
              final status = _room!['status'] as String? ?? 'group_all';
              final isAdminOnly = status == 'group_admin_only';

              return Container(
                height: MediaQuery.of(context).size.height * 0.8,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.borderSubtle,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      roomTitle,
                      style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _room!['card_id'] != null ? 'Campaign Group Chat' : 'Custom Group Chat',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 16),
                    TabBar(
                      labelColor: AppColors.accent,
                      unselectedLabelColor: AppColors.textMuted,
                      indicatorColor: AppColors.accent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabs: [
                        Tab(icon: Icon(Iconsax.info_circle), text: 'Info'),
                        Tab(
                          icon: const Icon(Iconsax.people),
                          text: 'Members (${_groupMembers.where((m) => m['status'] == 'joined').length})',
                        ),
                        Tab(icon: Icon(Iconsax.folder_open), text: 'Media'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Tab 1: Info & Settings
                          ListView(
                            children: [
                              Text(
                                'Description',
                                style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                roomDesc,
                                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                              ),
                              const Divider(height: 32),
                              
                              if (isCurrentUserAdmin) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Only Admin Can Message',
                                          style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Restrict messaging permissions',
                                          style: AppTextStyles.captionSm,
                                        ),
                                      ],
                                    ),
                                    Switch(
                                      value: isAdminOnly,
                                      activeColor: AppColors.accent,
                                      onChanged: (val) async {
                                        final newStatus = val ? 'group_admin_only' : 'group_all';
                                        await _chatService.updateGroupPermissions(widget.roomId, newStatus);
                                        if (mounted) {
                                          setState(() {
                                            _room!['status'] = newStatus;
                                          });
                                        }
                                        setSheetState(() {});
                                      },
                                    ),
                                  ],
                                ),
                                const Divider(height: 32),
                              ],
                              Text(
                                'Created by',
                                style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: AppAvatar(
                                  url: _room!['brand']?['avatar_url'],
                                  fallbackText: brandName,
                                  size: 36,
                                ),
                                title: Text(brandName, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                                subtitle: const Text('Brand Owner (Admin)', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),

                          // Tab 2: Members Tab
                          Column(
                            children: [
                              if (isCurrentUserAdmin) ...[
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () => _showAddMemberDialog(setSheetState),
                                    icon: const Icon(Icons.person_add_rounded, size: 18),
                                    label: const Text('Add Member', style: TextStyle(fontWeight: FontWeight.bold)),
                                    style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              Expanded(
                                child: _groupMembers.isEmpty
                                    ? Center(child: Text('No members in group', style: AppTextStyles.caption))
                                    : () {
                                        final joinedMembers = _groupMembers.where((m) => m['status'] == 'joined').toList();
                                        final pendingMembers = _groupMembers.where((m) => m['status'] == 'pending_invite').toList();

                                        return ListView(
                                          children: [
                                            if (joinedMembers.isNotEmpty) ...[
                                              Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                                child: Text(
                                                  'Active Members (${joinedMembers.length})',
                                                  style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                                ),
                                              ),
                                              ...joinedMembers.map((member) => _buildMemberTile(member, userId, isCurrentUserAdmin, setSheetState)),
                                            ],
                                            if (pendingMembers.isNotEmpty) ...[
                                              const Divider(height: 24),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                                child: Text(
                                                  'Pending Invites (${pendingMembers.length})',
                                                  style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold, color: AppColors.textMuted),
                                                ),
                                              ),
                                              ...pendingMembers.map((member) => _buildMemberTile(member, userId, isCurrentUserAdmin, setSheetState)),
                                            ],
                                          ],
                                        );
                                      }(),
                              ),
                            ],
                          ),

                          // Tab 3: Media Tab
                          ListView(
                            children: [
                              ExpansionTile(
                                leading: Icon(Icons.image_rounded, color: AppColors.accent),
                                title: Text('Photos (${imageMsgs.length})', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
                                children: [
                                  if (imageMsgs.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text('No shared photos', style: AppTextStyles.caption),
                                    )
                                  else
                                    GridView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      padding: const EdgeInsets.all(8),
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        crossAxisSpacing: 8,
                                        mainAxisSpacing: 8,
                                      ),
                                      itemCount: imageMsgs.length,
                                      itemBuilder: (context, idx) {
                                        final msg = imageMsgs[idx];
                                        final url = msg['attachment_url'] as String;
                                        return GestureDetector(
                                          onTap: () {
                                            Navigator.pop(ctx);
                                            _openImageViewer(url);
                                          },
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.network(url, fit: BoxFit.cover),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                              ExpansionTile(
                                leading: Icon(Icons.insert_drive_file_rounded, color: AppColors.accent),
                                title: Text('Documents (${fileMsgs.length})', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
                                children: [
                                  if (fileMsgs.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text('No shared documents', style: AppTextStyles.caption),
                                    )
                                  else
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: fileMsgs.length,
                                      itemBuilder: (context, idx) {
                                        final msg = fileMsgs[idx];
                                        final url = msg['attachment_url'] as String;
                                        final name = msg['content'] ?? 'Attachment';
                                        return ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                          leading: Icon(Icons.insert_drive_file_rounded, color: AppColors.accent, size: 20),
                                          title: Text(name, style: AppTextStyles.bodySm, maxLines: 1, overflow: TextOverflow.ellipsis),
                                          trailing: IconButton(
                                            icon: const Icon(Icons.download_rounded, size: 18),
                                            onPressed: () => _downloadFile(url, name),
                                          ),
                                          onTap: () => _launchURL(url),
                                        );
                                      },
                                    ),
                                ],
                              ),
                              ExpansionTile(
                                leading: Icon(Icons.headset_rounded, color: AppColors.accent),
                                title: Text('Voice Notes (${voiceMsgs.length})', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
                                children: [
                                  if (voiceMsgs.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text('No shared voice notes', style: AppTextStyles.caption),
                                    )
                                  else
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: voiceMsgs.length,
                                      itemBuilder: (context, idx) {
                                        final msg = voiceMsgs[idx];
                                        final duration = msg['payload']?['duration'] as int? ?? 0;
                                        return ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                          leading: Icon(Icons.mic_rounded, color: AppColors.accent, size: 20),
                                          title: Text('Voice Note (${duration}s)', style: AppTextStyles.bodySm),
                                          trailing: Text(
                                            msg['created_at'] != null
                                                ? DateFormat('MM/dd h:mm a').format(DateTime.parse(msg['created_at']).toLocal())
                                                : '',
                                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                              ExpansionTile(
                                leading: const Icon(Icons.link_rounded, color: Colors.blue),
                                title: Text('Links (${linkMsgs.length})', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
                                children: [
                                  if (linkMsgs.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text('No shared links', style: AppTextStyles.caption),
                                    )
                                  else
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: linkMsgs.length,
                                      itemBuilder: (context, idx) {
                                        final msg = linkMsgs[idx];
                                        final content = msg['content'] as String? ?? '';
                                        final match = linkRegExp.firstMatch(content);
                                        final url = match?.group(0) ?? '';
                                        return ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                          leading: const Icon(Icons.link_rounded, color: Colors.blue, size: 20),
                                          title: Text(url, style: AppTextStyles.bodySm.copyWith(color: Colors.blue, decoration: TextDecoration.underline), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          subtitle: Text(content, style: AppTextStyles.captionSm, maxLines: 2, overflow: TextOverflow.ellipsis),
                                          onTap: () => _launchURL(url),
                                        );
                                      },
                                    ),
                                ],
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
        );
      },
    );
  }

  Future<void> _showAddMemberDialog(StateSetter setSheetState) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final allProfilesRes = await SupabaseService.client
        .from('profiles')
        .select('id, display_name, avatar_url, role')
        .neq('id', user.id);
    final allProfiles = List<Map<String, dynamic>>.from(allProfilesRes);

    final existingUserIds = _groupMembers.map((m) => m['user_id'] as String).toSet();
    final inviteable = allProfiles.where((p) => !existingUserIds.contains(p['id'])).toList();

    if (!mounted) return;

    final selected = <String>{};
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Invite Members'),
              content: inviteable.isEmpty
                  ? const SizedBox(
                      height: 100,
                      child: Center(child: Text('All users are already in the group.')),
                    )
                  : SizedBox(
                      width: double.maxFinite,
                      height: 300,
                      child: ListView.builder(
                        itemCount: inviteable.length,
                        itemBuilder: (context, idx) {
                          final p = inviteable[idx];
                          final isChecked = selected.contains(p['id']);
                          return CheckboxListTile(
                            value: isChecked,
                            title: Text(p['display_name'] ?? 'User', style: AppTextStyles.body),
                            subtitle: Text((p['role'] ?? 'member').toString().toUpperCase(), style: AppTextStyles.captionSm),
                            secondary: AppAvatar(
                              url: p['avatar_url'],
                              fallbackText: p['display_name'] ?? 'U',
                              size: 32,
                            ),
                            onChanged: (val) {
                              setDialogState(() {
                                if (val == true) {
                                  selected.add(p['id']);
                                } else {
                                  selected.remove(p['id']);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          for (final uid in selected) {
                            try {
                              await _chatService.inviteUserToGroup(widget.roomId, uid);
                            } catch (e) {
                              print('Error inviting user $uid: $e');
                            }
                          }
                          final members = await _chatService.getGroupMembers(widget.roomId);
                          if (mounted) {
                            setState(() {
                              _groupMembers = members;
                            });
                            setSheetState(() {});
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                  child: const Text('Invite'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> member, String? userId, bool isCurrentUserAdmin, StateSetter setSheetState) {
    final profile = member['profiles'] as Map<String, dynamic>? ?? {};
    final name = profile['display_name'] ?? 'User';
    final roleStr = member['role'] as String? ?? 'member';
    final statusStr = member['status'] as String? ?? 'joined';
    final mutedUntil = member['muted_until'] as String?;
    final isMuted = mutedUntil != null && DateTime.tryParse(mutedUntil)?.isAfter(DateTime.now()) == true;

    String subtext = roleStr.toUpperCase();
    if (statusStr != 'joined') {
      subtext += ' • ${statusStr.replaceAll('_', ' ').toUpperCase()}';
    }
    if (isMuted) {
      subtext += ' • MUTED';
    }

    final isMe = member['user_id'] == userId;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: AppAvatar(
        url: profile['avatar_url'],
        fallbackText: name,
        size: 40,
      ),
      title: Text(
        isMe ? '$name (You)' : name,
        style: AppTextStyles.body.copyWith(
          fontWeight: roleStr == 'owner' || roleStr == 'admin'
              ? FontWeight.bold
              : FontWeight.normal,
        ),
      ),
      subtitle: Text(subtext, style: AppTextStyles.captionSm),
      trailing: (!isMe && isCurrentUserAdmin && roleStr != 'owner')
          ? IconButton(
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () => _showMemberActionsMenu(member, setSheetState),
            )
          : null,
    );
  }

  void _showMemberActionsMenu(Map<String, dynamic> member, StateSetter setSheetState) {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final targetUserId = member['user_id'] as String;
    final targetRole = member['role'] as String? ?? 'member';
    final targetDisplayName = member['profiles']?['display_name'] ?? 'User';

    final currentUserRole = _currentUserMemberInfo?['role'] as String? ?? 'member';
    final isCurrentUserOwner = currentUserRole == 'owner' || _room!['brand_id'] == user.id;
    final isCurrentUserAdmin = currentUserRole == 'admin' || isCurrentUserOwner;

    if (targetUserId == user.id) return;

    bool canManage = false;
    if (isCurrentUserOwner) {
      canManage = true;
    } else if (isCurrentUserAdmin && targetRole == 'member') {
      canManage = true;
    }

    if (!canManage) return;

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
              Text(
                'Manage $targetDisplayName',
                style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (isCurrentUserOwner) ...[
                ListTile(
                  leading: Icon(targetRole == 'admin' ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded),
                  title: Text(targetRole == 'admin' ? 'Demote to Member' : 'Promote to Admin', style: AppTextStyles.body),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final newRole = targetRole == 'admin' ? 'member' : 'admin';
                    await _chatService.updateMemberRole(widget.roomId, targetUserId, newRole);
                    final members = await _chatService.getGroupMembers(widget.roomId);
                    if (mounted) {
                      setState(() {
                        _groupMembers = members;
                      });
                      setSheetState(() {});
                    }
                  },
                ),
              ],
              ListTile(
                leading: const Icon(Icons.volume_off_rounded),
                title: Text(member['muted_until'] != null ? 'Unmute Member' : 'Mute Member', style: AppTextStyles.body),
                onTap: () {
                  Navigator.pop(ctx);
                  if (member['muted_until'] != null) {
                    _muteMemberAction(targetUserId, null, setSheetState);
                  } else {
                    _showMuteDurationDialog(targetUserId, setSheetState);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_remove_rounded, color: Colors.orangeAccent),
                title: const Text('Remove from Group', style: TextStyle(color: Colors.orangeAccent)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _chatService.removeMember(widget.roomId, targetUserId);
                  final members = await _chatService.getGroupMembers(widget.roomId);
                  if (mounted) {
                    setState(() {
                      _groupMembers = members;
                    });
                    setSheetState(() {});
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.block_rounded, color: Colors.redAccent),
                title: const Text('Ban Member', style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _chatService.banMember(widget.roomId, targetUserId);
                  final members = await _chatService.getGroupMembers(widget.roomId);
                  if (mounted) {
                    setState(() {
                      _groupMembers = members;
                    });
                    setSheetState(() {});
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMuteDurationDialog(String targetUserId, StateSetter setSheetState) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Mute Duration'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Mute for 1 Hour'),
                onTap: () {
                  Navigator.pop(ctx);
                  _muteMemberAction(targetUserId, DateTime.now().add(const Duration(hours: 1)), setSheetState);
                },
              ),
              ListTile(
                title: const Text('Mute for 24 Hours'),
                onTap: () {
                  Navigator.pop(ctx);
                  _muteMemberAction(targetUserId, DateTime.now().add(const Duration(hours: 24)), setSheetState);
                },
              ),
              ListTile(
                title: const Text('Mute for 7 Days'),
                onTap: () {
                  Navigator.pop(ctx);
                  _muteMemberAction(targetUserId, DateTime.now().add(const Duration(days: 7)), setSheetState);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _muteMemberAction(String targetUserId, DateTime? until, StateSetter setSheetState) async {
    await _chatService.muteMember(widget.roomId, targetUserId, until);
    final members = await _chatService.getGroupMembers(widget.roomId);
    if (mounted) {
      setState(() {
        _groupMembers = members;
      });
      setSheetState(() {});
    }
  }

  void _showStarredMessages() {
    final userId = ref.read(authProvider).user?.id;
    final starred = _messages.where((msg) {
      final starredBy = msg['payload']?['starred_by'] as List<dynamic>?;
      return starredBy != null && starredBy.contains(userId);
    }).toList();

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Starred Messages (${starred.length})', style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold)),
              const Divider(height: 24),
              if (starred.isEmpty)
                Expanded(
                  child: Center(
                    child: Text('No starred messages in this chat.', style: AppTextStyles.caption),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: starred.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (ctx, idx) {
                      final msg = starred[idx];
                      final sender = msg['sender_id'] == userId ? 'You' : (msg['sender']?['display_name'] ?? 'User');
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(sender, style: AppTextStyles.label.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold)),
                                Text(
                                  msg['created_at'] != null ? DateFormat('MM/dd h:mm a').format(DateTime.parse(msg['created_at']).toLocal()) : '',
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(msg['content'] ?? '', style: AppTextStyles.body),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showFilePicker() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                _buildPickerTile(
                  icon: Icons.camera_alt_rounded,
                  color: Colors.redAccent,
                  label: 'Camera',
                  subtitle: 'Take a photo',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadImage(ImageSource.camera);
                  },
                ),
                _buildPickerTile(
                  icon: Icons.photo_library_rounded,
                  color: Colors.pinkAccent,
                  label: 'Gallery',
                  subtitle: 'Pick photos & videos',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadImage(ImageSource.gallery);
                  },
                ),
                _buildPickerTile(
                  icon: Icons.insert_drive_file_rounded,
                  color: Colors.deepPurpleAccent,
                  label: 'Files',
                  subtitle: 'Documents, PDFs, and more',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadFile();
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPickerTile({
    required IconData icon,
    required Color color,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(label, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted, fontSize: 12)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Future<void> _pickAndUploadFile() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) return;

      setState(() {
        _uploading = true;
        _uploadingLabel = 'Uploading ${file.name}...';
      });
      _scrollToBottom();

      final fileExt = file.extension ?? 'bin';
      final fileName = '${DateTime.now().microsecondsSinceEpoch}.$fileExt';
      final path = '${widget.roomId}/$fileName';

      // Determine content type
      String contentType = 'application/octet-stream';
      final ext = fileExt.toLowerCase();
      if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
        contentType = 'image/$ext';
      } else if (['mp4', 'mov', 'avi', 'webm'].contains(ext)) {
        contentType = 'video/$ext';
      } else if (ext == 'pdf') {
        contentType = 'application/pdf';
      } else if (['doc', 'docx'].contains(ext)) {
        contentType = 'application/msword';
      }

      // Determine attachment type
      String attachmentType = 'file';
      if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
        attachmentType = 'image';
      } else if (['mp4', 'mov', 'avi', 'webm'].contains(ext)) {
        attachmentType = 'file';
      } else if (ext == 'pdf' || ['doc', 'docx'].contains(ext)) {
        attachmentType = 'document';
      }

      await SupabaseService.client.storage
          .from('message-attachments')
          .uploadBinary(path, file.bytes!, fileOptions: FileOptions(contentType: contentType));

      final publicUrl = SupabaseService.client.storage
          .from('message-attachments')
          .getPublicUrl(path);

      await _chatService.updateLastSeen(user.id);
      await _chatService.sendMessage(
        roomId: widget.roomId,
        senderId: user.id,
        content: 'Shared a ${attachmentType == 'image' ? 'photo' : file.name}',
        attachmentUrl: publicUrl,
        attachmentType: attachmentType,
      );

      final msgs = await _chatService.getMessages(widget.roomId, limit: 100);
      if (mounted) {
        setState(() {
          _messages = msgs;
          _uploading = false;
          _uploadingLabel = '';
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Error picking/uploading file: $e');
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadingLabel = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload file: $e')),
        );
      }
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: source);
      if (image == null) return;

      setState(() {
        _uploading = true;
        _uploadingLabel = 'Uploading photo...';
      });
      _scrollToBottom();

      final bytes = await image.readAsBytes();
      final fileExt = image.name.split('.').last;
      final fileName = '${DateTime.now().microsecondsSinceEpoch}.$fileExt';
      final path = '${widget.roomId}/$fileName';

      // Upload to Supabase Storage bucket 'message-attachments'
      await SupabaseService.client.storage
          .from('message-attachments')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$fileExt'),
          );

      // Get Public URL
      final publicUrl = SupabaseService.client.storage
          .from('message-attachments')
          .getPublicUrl(path);

      // Send the message with attachment
      await _chatService.updateLastSeen(user.id);
      await _chatService.sendMessage(
        roomId: widget.roomId,
        senderId: user.id,
        content: 'Shared a photo',
        attachmentUrl: publicUrl,
        attachmentType: 'image',
      );

      final msgs = await _chatService.getMessages(widget.roomId, limit: 100);
      if (mounted) {
        setState(() {
          _messages = msgs;
          _uploading = false;
          _uploadingLabel = '';
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Error picking/uploading image: $e');
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadingLabel = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
    }
  }

  Future<void> _addMilestone() async {
    final ctrl = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Add Milestone'),
        content: TextField(controller: ctrl, autofocus: true, style: AppTextStyles.body, decoration: const InputDecoration(hintText: 'Milestone title')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Add')),
        ],
      ),
    );
    if (title != null && title.isNotEmpty) {
      await _chatService.createMilestone({'room_id': widget.roomId, 'title': title, 'status': 'pending'});
      final milestones = await _chatService.getMilestones(widget.roomId);
      if (mounted) setState(() => _milestones = milestones);
    }
  }

  Future<void> _toggleMilestone(Map<String, dynamic> m) async {
    final newStatus = m['status'] == 'completed' ? 'pending' : 'completed';
    await _chatService.updateMilestoneStatus(m['id'] as String, newStatus);
    final milestones = await _chatService.getMilestones(widget.roomId);
    if (mounted) setState(() => _milestones = milestones);
  }
}

class VoiceNotePlayerWidget extends StatefulWidget {
  final String url;
  final int duration;
  final bool isMe;
  const VoiceNotePlayerWidget({
    super.key,
    required this.url,
    required this.duration,
    required this.isMe,
  });

  @override
  State<VoiceNotePlayerWidget> createState() => _VoiceNotePlayerWidgetState();
}

class _VoiceNotePlayerWidgetState extends State<VoiceNotePlayerWidget> {
  bool _isPlaying = false;
  int _position = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _togglePlay() {
    if (_isPlaying) {
      _timer?.cancel();
      setState(() {
        _isPlaying = false;
      });
    } else {
      setState(() {
        _isPlaying = true;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_position >= widget.duration) {
          _timer?.cancel();
          setState(() {
            _isPlaying = false;
            _position = 0;
          });
        } else {
          setState(() {
            _position++;
          });
        }
      });
    }
  }

  String _formatDuration(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.duration > 0 ? _position / widget.duration : 0.0;
    final color = widget.isMe ? Colors.white : AppColors.accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      width: 160, // Fixed width constraint for audio bubble
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: color,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _togglePlay,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(
                  size: const Size(120, 20),
                  painter: WaveformPainter(
                    progress: progress,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(
                        fontSize: 9,
                        color: widget.isMe ? Colors.white70 : AppColors.textMuted,
                      ),
                    ),
                    Text(
                      _formatDuration(widget.duration),
                      style: TextStyle(
                        fontSize: 9,
                        color: widget.isMe ? Colors.white70 : AppColors.textMuted,
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
  }
}

class WaveformPainter extends CustomPainter {
  final double progress;
  final Color color;
  WaveformPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const barCount = 15;
    final barWidth = size.width / barCount;
    final heights = [
      0.3, 0.5, 0.8, 0.4, 0.6, 0.9, 0.5, 0.7, 0.3, 0.6, 0.8, 0.4, 0.7, 0.5, 0.3
    ];

    for (int i = 0; i < barCount; i++) {
      final x = i * barWidth + barWidth / 2;
      final h = size.height * heights[i];
      final top = (size.height - h) / 2;
      final bottom = top + h;

      final isPast = (i / barCount) <= progress;
      canvas.drawLine(
        Offset(x, top),
        Offset(x, bottom),
        isPast ? activePaint : paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _SimulatedCallScreen extends StatefulWidget {
  final String roomName;
  final String? avatarUrl;
  final bool isVideo;

  const _SimulatedCallScreen({
    required this.roomName,
    this.avatarUrl,
    required this.isVideo,
  });

  @override
  State<_SimulatedCallScreen> createState() => _SimulatedCallScreenState();
}

class _SimulatedCallScreenState extends State<_SimulatedCallScreen> {
  bool _isMuted = false;
  late bool _cameraOn;
  bool _isScreenSharing = false;
  bool _isSpeaker = true;
  String _status = 'Connecting...';
  int _seconds = 0;
  Timer? _timer;
  Timer? _connectTimer;

  @override
  void initState() {
    super.initState();
    _cameraOn = widget.isVideo;
    // Simulate connection lag
    _connectTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _status = 'Connected';
        });
        _startTimer();
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _seconds++;
        });
      }
    });
  }

  @override
  void dispose() {
    _connectTimer?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int totalSecs) {
    final m = totalSecs ~/ 60;
    final s = totalSecs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final hasVisualFeed = _cameraOn || _isScreenSharing;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B16),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded, color: Colors.white54, size: 14),
                      const SizedBox(width: 4),
                      const Text(
                        'End-to-End Encrypted',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                  if (hasVisualFeed)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isScreenSharing ? 'LIVE SHARE' : 'CAM LIVE',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Room Title / Info
            const SizedBox(height: 16),
            Text(
              widget.roomName,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _status == 'Connected' ? _formatTime(_seconds) : _status,
              style: TextStyle(
                color: _status == 'Connected' ? AppColors.accent : Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 32),

            // Video/Screen or Avatar Center Display
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: hasVisualFeed
                      ? Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFF16162A),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _isScreenSharing ? Colors.greenAccent : AppColors.accent,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (_isScreenSharing ? Colors.greenAccent : AppColors.accent).withOpacity(0.15),
                                blurRadius: 16,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Background pattern placeholder for camera/screen stream
                                if (_isScreenSharing)
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.present_to_all_rounded, size: 64, color: Colors.greenAccent),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Presenting Screen',
                                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Sharing your display in real-time',
                                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                      ),
                                    ],
                                  )
                                else
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.videocam_rounded, size: 64, color: Colors.white70),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Camera Stream Active',
                                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Video capture is on',
                                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                      ),
                                    ],
                                  ),

                                // Small self PIP
                                Positioned(
                                  right: 16,
                                  bottom: 16,
                                  child: Container(
                                    width: 80,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: Colors.black45,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        _cameraOn ? Icons.person_rounded : Icons.videocam_off_rounded,
                                        color: Colors.white70,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.95, end: 1.05),
                          duration: const Duration(seconds: 1),
                          curve: Curves.easeInOut,
                          builder: (context, scale, child) {
                            return Transform.scale(
                              scale: _status == 'Connecting...' ? scale : 1.0,
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.accent.withOpacity(0.15),
                                    width: 4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.accent.withOpacity(0.1),
                                      blurRadius: 24,
                                      spreadRadius: 8,
                                    ),
                                  ],
                                ),
                                child: widget.avatarUrl != null
                                    ? AppAvatar(
                                        url: widget.avatarUrl,
                                        fallbackText: widget.roomName,
                                        size: 130,
                                      )
                                    : CircleAvatar(
                                        radius: 65,
                                        backgroundColor: AppColors.accent.withOpacity(0.15),
                                        child: Icon(
                                          Icons.group_rounded,
                                          color: AppColors.accent,
                                          size: 54,
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // In-Call Controls Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              decoration: const BoxDecoration(
                color: Color(0xFF121224),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Mute
                      _buildControlBtn(
                        icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        active: _isMuted,
                        onTap: () => setState(() => _isMuted = !_isMuted),
                      ),
                      // Video
                      _buildControlBtn(
                        icon: _cameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                        active: _cameraOn,
                        onTap: () => setState(() => _cameraOn = !_cameraOn),
                      ),
                      // Screen Share
                      _buildControlBtn(
                        icon: Icons.present_to_all_rounded,
                        active: _isScreenSharing,
                        onTap: () => setState(() => _isScreenSharing = !_isScreenSharing),
                      ),
                      // Speaker
                      _buildControlBtn(
                        icon: _isSpeaker ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                        active: _isSpeaker,
                        onTap: () => setState(() => _isSpeaker = !_isSpeaker),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Hang up Button
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent,
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.call_end_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlBtn({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? Colors.white : Colors.white24,
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: active ? const Color(0xFF0B0B16) : Colors.white,
          size: 22,
        ),
      ),
    );
  }
}