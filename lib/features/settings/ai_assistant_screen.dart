import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/supabase_service.dart';
import '../../core/config/remote_config_service.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  _ChatMessage({required this.text, required this.isUser, required this.timestamp});
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _loadingContext = true;
  bool _loadingResponse = false;

  // Context variables
  Map<String, dynamic>? _profileContext;
  List<dynamic> _cardsContext = [];
  List<dynamic> _appsContext = [];
  List<dynamic> _roomsContext = [];

  // Gemini API Credentials
  static String get _geminiApiKey {
    const key = String.fromEnvironment('GEMINI_API_KEY');
    if (key.isNotEmpty) return key;
    return RemoteConfigService.get('gemini_api_key', '');
  }
  static const String _geminiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent';

  @override
  void initState() {
    super.initState();
    _loadUserContext();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserContext() async {
    setState(() => _loadingContext = true);
    try {
      final user = ref.read(authProvider).user;
      final role = ref.read(authProvider).role ?? 'influencer';
      if (user == null) return;

      // 1. Fetch Profile Details
      final profile = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      _profileContext = profile;

      // 2. Fetch Cards
      final cards = await SupabaseService.client
          .from('cards')
          .select('*, brand:profiles(display_name)')
          .filter('deleted_at', 'is', null)
          .order('created_at', ascending: false);
      _cardsContext = cards;

      // 3. Fetch Applications
      if (role == 'influencer') {
        final apps = await SupabaseService.client
            .from('applications')
            .select('*, card:cards(title, budget_range), brand:profiles!applications_influencer_id_fkey(display_name)')
            .eq('influencer_id', user.id)
            .filter('deleted_at', 'is', null);
        _appsContext = apps;
      } else {
        final apps = await SupabaseService.client
            .from('applications')
            .select('*, card:cards!inner(title, brand_id), influencer:profiles(display_name)')
            .eq('card.brand_id', user.id)
            .filter('deleted_at', 'is', null);
        _appsContext = apps;
      }

      // 4. Fetch Rooms
      final rooms = await SupabaseService.client
          .from('rooms')
          .select('*, card:cards(title), brand:profiles!rooms_brand_id_fkey(display_name), influencer:profiles!rooms_influencer_id_fkey(display_name)')
          .or('brand_id.eq.${user.id},influencer_id.eq.${user.id}')
          .filter('deleted_at', 'is', null);
      _roomsContext = rooms;

      // 5. Fetch Chat History
      final history = await SupabaseService.client
          .from('ai_assistant_chats')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: true);

      setState(() {
        _messages.clear();
        if (history.isNotEmpty) {
          for (final h in history) {
            final isUser = h['is_user'] as bool;
            final text = h['message'] as String;
            final timestamp = DateTime.parse(h['created_at']);

            if (_messages.isNotEmpty && _messages.last.isUser == isUser) {
              // Merge consecutive messages from the same role
              final lastMsg = _messages.last;
              _messages[_messages.length - 1] = _ChatMessage(
                text: "${lastMsg.text}\n$text",
                isUser: isUser,
                timestamp: timestamp,
              );
            } else {
              _messages.add(_ChatMessage(
                text: text,
                isUser: isUser,
                timestamp: timestamp,
              ));
            }
          }
        } else {
          final welcomeText = "Hello! I am your Promo AI Assistant. I have loaded your profile details, campaigns, applications, and chat rooms. Ask me anything!";
          _messages.add(_ChatMessage(
            text: welcomeText,
            isUser: false,
            timestamp: DateTime.now(),
          ));
          // Save welcome message in DB in background
          SupabaseService.client.from('ai_assistant_chats').insert({
            'user_id': user.id,
            'message': welcomeText,
            'is_user': false,
          }).then((_) {}).catchError((_) {});
        }
        _loadingContext = false;
      });

      _scrollToBottom();
    } catch (e) {
      debugPrint('[AI ASSISTANT CONTEXT ERROR] $e');
      setState(() => _loadingContext = false);
    }
  }

  String _buildSystemInstruction() {
    final role = ref.read(authProvider).role ?? 'influencer';
    final contextMap = {
      "user_role": role,
      "profile": {
        "display_name": _profileContext?['display_name'] ?? 'User',
        "bio": _profileContext?['bio'] ?? '',
        "location": _profileContext?['location'] ?? '',
        "niches": _profileContext?['niches'] ?? [],
        "platforms": _profileContext?['platforms'] ?? [],
        "account_status": _profileContext?['account_status'] ?? 'active',
      },
      "active_campaign_listings": _cardsContext.map((c) => {
        "id": c['id'],
        "title": c['title'],
        "description": c['description'],
        "category": c['category'],
        "budget_range": c['budget_range'],
        "status": c['status'],
        "brand_name": c['brand']?['display_name'] ?? 'Unknown Brand',
      }).toList(),
      "application_history": _appsContext.map((a) => {
        "id": a['id'],
        "card_title": a['card']?['title'] ?? 'Campaign',
        "pitch_message": a['pitch_message'] ?? '',
        "proposed_rate": a['proposed_rate'] ?? '',
        "status": a['status'],
        "partner_name": a['influencer']?['display_name'] ?? a['brand']?['display_name'] ?? 'Partner',
      }).toList(),
      "chat_rooms": _roomsContext.map((r) => {
        "id": r['id'],
        "card_title": r['card']?['title'] ?? 'Direct Chat',
        "brand_name": r['brand']?['display_name'] ?? 'Brand',
        "influencer_name": r['influencer']?['display_name'] ?? 'Influencer',
      }).toList(),
    };

    return '''
You are "Promo AI Assistant", a helpful, friendly, and expert assistant built inside the settings of the Promo app.
Your task is to answer user queries based on the following real-time account and platform context.

User Role: $role
Account Context (JSON format):
${const JsonEncoder.withIndent('  ').convert(contextMap)}

Guidelines:
1. Always base your answers on the provided Account Context.
2. If the user asks about active campaigns, refer to "active_campaign_listings".
3. If they ask about applications, refer to "application_history".
4. If they ask about who they chat with, refer to "chat_rooms".
5. Keep your tone professional, concise, encouraging, and clear.
6. When the user asks to see, search, or list campaigns, applications, or chat partners:
   - You MUST find the matching data in the Account Context.
   - You MUST output the matching items as a raw JSON array block.
   - Example output:
   Yes, here are the matching details:
   [
     {
       "type": "campaign" | "application" | "chat",
       "id": "item_id_uuid",
       "title": "Campaign/Room/App Title",
       "subtitle": "Niche/Brand/Partner name",
       "status": "active" | "accepted" | "pending" | "rejected" | null,
       "stat": "Budget/Rate/Last message",
       "pitch": "Pitch text for application if present"
     }
   ]
   - CRITICAL: Never omit the JSON array or format it as normal text. Always include this JSON block format so the system can render them in a Bento Grid.
7. If the user asks to perform actions like applying or modifying things, explain that you are a chat agent and can guide them, but they need to tap the corresponding options in the app.
''';
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final user = ref.read(authProvider).user;
    if (user != null) {
      SupabaseService.client.from('ai_assistant_chats').insert({
        'user_id': user.id,
        'message': text.trim(),
        'is_user': true,
      }).then((_) {}).catchError((e) {
        debugPrint('[AI CHAT DB SAVE USER ERROR] $e');
      });
    }

    final userMessage = _ChatMessage(text: text.trim(), isUser: true, timestamp: DateTime.now());
    setState(() {
      _messages.add(userMessage);
      _loadingResponse = true;
      _messageCtrl.clear();
    });
    _scrollToBottom();

    final apiKey = _geminiApiKey;
    if (apiKey.isEmpty) {
      setState(() {
        _messages.add(
          _ChatMessage(
            text: "Gemini API Key is not configured. Please configure GEMINI_API_KEY via dart-define or platform_config.",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _loadingResponse = false;
      });
      return;
    }

    try {
      final systemInstruction = _buildSystemInstruction();

      // Format conversation history for Gemini API (must alternate roles and start with 'user')
      final List<Map<String, dynamic>> contents = [];
      String? lastRole;
      for (final msg in _messages) {
        final currentRole = msg.isUser ? "user" : "model";
        if (currentRole == "model" && lastRole == null) {
          // Skip leading model/assistant messages so we start with 'user'
          continue;
        }
        
        if (currentRole == lastRole) {
          // Merge consecutive messages from the same sender
          final lastParts = contents.last['parts'] as List<dynamic>;
          final lastText = lastParts[0]['text'] as String;
          lastParts[0]['text'] = "$lastText\n${msg.text}";
        } else {
          contents.add({
            "role": currentRole,
            "parts": [{"text": msg.text}],
          });
          lastRole = currentRole;
        }
      }

      final response = await http.post(
        Uri.parse(_geminiUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-goog-api-key': _geminiApiKey,
        },
        body: jsonEncode({
          "contents": contents,
          "systemInstruction": {
            "parts": [{"text": systemInstruction}]
          }
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final candidates = data['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          if (content != null) {
            final parts = content['parts'] as List<dynamic>?;
            if (parts != null && parts.isNotEmpty) {
              final replyText = parts[0]['text'] as String? ?? 'No reply generated.';
              
              if (user != null) {
                SupabaseService.client.from('ai_assistant_chats').insert({
                  'user_id': user.id,
                  'message': replyText,
                  'is_user': false,
                }).then((_) {}).catchError((e) {
                  debugPrint('[AI CHAT DB SAVE AI RESPONSE ERROR] $e');
                });
              }

              setState(() {
                _messages.add(_ChatMessage(text: replyText, isUser: false, timestamp: DateTime.now()));
              });
            }
          }
        }
      } else {
        setState(() {
          _messages.add(
            _ChatMessage(
              text: "Sorry, I received an error from the AI service. Status code: ${response.statusCode}",
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(
          _ChatMessage(
            text: "Sorry, I had trouble connecting. Please check your internet connection.",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    } finally {
      setState(() => _loadingResponse = false);
      _scrollToBottom();
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

  @override
  Widget build(BuildContext context) {
    final role = ref.read(authProvider).role ?? 'influencer';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<String> suggestions = role == 'influencer'
        ? [
            'Any active food campaigns?',
            'List my applications status',
            'Show my active chat partners',
          ]
        : [
            'Show my campaign listings',
            'Check received applications',
            'Show active chat rooms',
          ];

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : const Color(0xFFF9FAFB),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.purple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Iconsax.cpu, color: AppColors.purple, size: 20),
            ),
            const SizedBox(width: 8),
            Text(
              'Promo AI Assistant',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.refresh, size: 18),
            onPressed: _loadUserContext,
          ),
        ],
      ),
      body: _loadingContext
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading account details into AI context...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : Column(
              children: [
                // Chat Message List
                Expanded(
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, idx) {
                      final msg = _messages[idx];
                      return _buildMessageBubble(msg);
                    },
                  ),
                ),

                // Typing indicator
                if (_loadingResponse)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF202024) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('AI is typing', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                              const SizedBox(width: 4),
                              const SizedBox(
                                width: 8,
                                height: 8,
                                child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Suggestion chips
                if (_messages.length == 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: suggestions.map((text) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: ActionChip(
                              label: Text(text, style: const TextStyle(fontSize: 12)),
                              backgroundColor: AppColors.surface,
                              onPressed: () => _sendMessage(text),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                // Input bar
                SafeArea(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageCtrl,
                            textInputAction: TextInputAction.send,
                            onSubmitted: _sendMessage,
                            decoration: InputDecoration(
                              hintText: 'Type your message...',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(100)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF16161A) : const Color(0xFFF3F4F6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Iconsax.send_1, color: AppColors.purple),
                          onPressed: () => _sendMessage(_messageCtrl.text),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Resilient JSON bento grid data extraction
    List<Map<String, dynamic>> items = [];
    String plainText = msg.text;

    int startIdx = msg.text.indexOf('[');
    int endIdx = msg.text.lastIndexOf(']');
    if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
      final potentialJson = msg.text.substring(startIdx, endIdx + 1).trim();
      try {
        final parsed = jsonDecode(potentialJson);
        if (parsed is List) {
          final list = parsed
              .where((e) => e is Map && e.containsKey('id') && e.containsKey('title'))
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

          if (list.isNotEmpty) {
            items = list;
            // Clean plainText of the JSON block
            plainText = (msg.text.substring(0, startIdx) + msg.text.substring(endIdx + 1))
                .replaceAll(RegExp(r'```[a-zA-Z_]*'), '') // Strip empty backticks
                .trim();
          }
        }
      } catch (e) {
        debugPrint('[AI BENTO JSON PARSE ERROR] $e');
      }
    }

    if (plainText.isEmpty && items.isNotEmpty) {
      plainText = "Here are the details from your account:";
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!msg.isUser) ...[
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.purple.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Iconsax.cpu, color: AppColors.purple, size: 14),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: msg.isUser
                        ? AppColors.purple
                        : (isDark ? const Color(0xFF202024) : const Color(0xFFF3F4F6)),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(msg.isUser ? 16 : 0),
                      bottomRight: Radius.circular(msg.isUser ? 0 : 16),
                    ),
                  ),
                  child: Text(
                    plainText,
                    style: AppTextStyles.body.copyWith(
                      color: msg.isUser ? Colors.white : AppColors.textPrimary,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildBentoGrid(items),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildBentoGrid(List<Map<String, dynamic>> items) {
    final List<Widget> gridItems = [];
    int i = 0;

    while (i < items.length) {
      final type = items[i]['type'] ?? 'campaign';
      
      // If it is an application, it usually has a pitch message and proposed rate details.
      // Render applications as full-width bento blocks to display text properly.
      if (type == 'application') {
        gridItems.add(_buildBentoCard(items[i], isFullWidth: true));
        i++;
      } else {
        // Stagger campaigns/chats: 1 full-width, then 2 half-width, then 1 full-width...
        if (i % 3 == 0) {
          gridItems.add(_buildBentoCard(items[i], isFullWidth: true));
          i++;
        } else {
          if (i + 1 < items.length && items[i + 1]['type'] != 'application') {
            gridItems.add(Row(
              children: [
                Expanded(child: _buildBentoCard(items[i], isFullWidth: false)),
                const SizedBox(width: 10),
                Expanded(child: _buildBentoCard(items[i + 1], isFullWidth: false)),
              ],
            ));
            i += 2;
          } else {
            gridItems.add(_buildBentoCard(items[i], isFullWidth: true));
            i++;
          }
        }
      }
      gridItems.add(const SizedBox(height: 10));
    }

    return Padding(
      padding: const EdgeInsets.only(left: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: gridItems,
      ),
    );
  }

  Widget _buildBentoCard(Map<String, dynamic> item, {required bool isFullWidth}) {
    final title = item['title'] ?? 'Title';
    final subtitle = item['subtitle'] ?? 'Subtitle';
    final type = item['type'] ?? 'campaign';
    final status = item['status'] as String?;
    final stat = item['stat'] as String?;
    final pitch = item['pitch'] as String?;

    IconData cardIcon = Iconsax.briefcase;
    if (type == 'chat') cardIcon = Iconsax.message;
    if (type == 'application') cardIcon = Iconsax.document_text;

    // Premium light coloring configuration: light cream-lavender card background with high contrast dark text
    final cardBg = const Color(0xFFF7F6FB);
    const titleColor = Color(0xFF1E1C38);
    const subtitleColor = Color(0xFF555375);
    final borderColor = AppColors.purple.withValues(alpha: 0.35);

    Widget? statusBadge;
    if (status != null) {
      Color badgeBg = const Color(0xFFF3F4F6);
      Color badgeText = const Color(0xFF4B5563);
      String badgeLabel = status.toUpperCase();

      if (status == 'accepted' || status == 'active') {
        badgeBg = const Color(0xFFDCFCE7);
        badgeText = const Color(0xFF166534);
      } else if (status == 'pending') {
        badgeBg = const Color(0xFFFEF3C7);
        badgeText = const Color(0xFF92400E);
      } else if (status == 'rejected') {
        badgeBg = const Color(0xFFFEE2E2);
        badgeText = const Color(0xFF991B1B);
      }

      statusBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: badgeBg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          badgeLabel,
          style: GoogleFonts.inter(
            fontSize: 8.5,
            fontWeight: FontWeight.bold,
            color: badgeText,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        final role = ref.read(authProvider).role ?? 'influencer';
        if (type == 'campaign') {
          if (role == 'influencer') {
            context.push('/influencer/discover/${item['id']}');
          } else {
            context.push('/brand/cards/${item['id']}');
          }
        } else if (type == 'chat') {
          context.push('/$role/chats/${item['id']}');
        } else if (type == 'application') {
          context.push('/$role/applications');
        }
      },
      child: Container(
        height: isFullWidth ? null : 130,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.purple.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(cardIcon, color: AppColors.purple, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (statusBadge != null) ...[
                      const SizedBox(width: 6),
                      statusBadge,
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: subtitleColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isFullWidth && pitch != null && pitch.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '"$pitch"',
                    style: GoogleFonts.inter(
                      color: subtitleColor.withValues(alpha: 0.8),
                      fontSize: 10.5,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
            if (isFullWidth) const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  type.toString().toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: AppColors.purple.withValues(alpha: 0.6),
                    letterSpacing: 0.8,
                  ),
                ),
                if (stat != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      stat,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: AppColors.purple,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
