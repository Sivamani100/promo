import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/app_snackbar.dart';

class McpKeysSettingsScreen extends ConsumerStatefulWidget {
  const McpKeysSettingsScreen({super.key});

  @override
  ConsumerState<McpKeysSettingsScreen> createState() => _McpKeysSettingsScreenState();
}

class _McpKeysSettingsScreenState extends ConsumerState<McpKeysSettingsScreen> {
  final _keyNameCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _keys = [];
  String _selectedExpiry = '7_days'; // 24_hours, 7_days, 30_days, never
  bool _scopeReadOnly = true;
  bool _scopeFullAccess = false;

  @override
  void initState() {
    super.initState();
    _loadMcpKeys();
  }

  @override
  void dispose() {
    _keyNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMcpKeys() async {
    setState(() => _loading = true);
    try {
      final user = ref.read(authProvider).user;
      if (user == null) return;

      final data = await SupabaseService.client
          .from('mcp_keys')
          .select()
          .eq('user_id', user.id)
          .filter('revoked_at', 'is', null)
          .order('created_at', ascending: false);

      setState(() {
        _keys = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Failed to load keys: $e');
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _createMcpKey(String name) async {
    if (name.trim().isEmpty) return;
    setState(() => _saving = true);

    DateTime? expiresAt;
    final now = DateTime.now().toUtc();
    if (_selectedExpiry == '24_hours') {
      expiresAt = now.add(const Duration(hours: 24));
    } else if (_selectedExpiry == '7_days') {
      expiresAt = now.add(const Duration(days: 7));
    } else if (_selectedExpiry == '30_days') {
      expiresAt = now.add(const Duration(days: 30));
    }

    final List<String> scopes = [];
    if (_scopeReadOnly) scopes.add('read_only');
    if (_scopeFullAccess) scopes.add('full_access');
    if (scopes.isEmpty) scopes.add('read_only'); // Fail-safe default

    try {
      final res = await SupabaseService.client.rpc('generate_mcp_key', params: {
        'p_name': name.trim(),
        'p_expires_at': expiresAt?.toIso8601String(),
        'p_scopes': scopes,
      });

      if (res != null && res.isNotEmpty) {
        final rawKey = res[0]['raw_key'] as String;
        await _loadMcpKeys();
        if (mounted) {
          _showNewKeyBottomSheet(name, rawKey, scopes);
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Failed to generate key: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _revokeKey(String keyId) async {
    setState(() => _saving = true);
    try {
      await SupabaseService.client
          .from('mcp_keys')
          .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', keyId);

      await _loadMcpKeys();
      if (mounted) {
        AppSnackbar.success(context, 'Key revoked successfully.');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Failed to revoke key: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showNewKeyBottomSheet(String name, String rawKey, List<String> scopes) {
    final gatewayUrl = '${SupabaseService.supabaseUrl}/functions/v1/mcp-gateway';
    final openApiSpec = {
      "openapi": "3.0.0",
      "info": {
        "title": "Promo AI Gateway API",
        "version": "1.0.0",
        "description": "API for AI agents to query campaigns, check applications, view chats, and submit pitches."
      },
      "servers": [
        {
          "url": gatewayUrl
        }
      ],
      "paths": {
        "/cards": {
          "get": {
            "summary": "Fetch campaigns",
            "description": "Returns campaign cards. Influencers see active ones; Brands see owned ones.",
            "parameters": [
              {
                "name": "query",
                "in": "query",
                "required": false,
                "schema": {
                  "type": "string"
                },
                "description": "Optional keyword search query"
              }
            ],
            "responses": {
              "200": {
                "description": "Success"
              }
            }
          }
        },
        "/applications": {
          "get": {
            "summary": "Fetch applications history",
            "responses": {
              "200": {
                "description": "Success"
              }
            }
          }
        },
        "/chats": {
          "get": {
            "summary": "Fetch chat rooms index",
            "responses": {
              "200": {
                "description": "Success"
              }
            }
          }
        },
        "/apply": {
          "post": {
            "summary": "Submit application to a campaign",
            "description": "Apply to a campaign. Requires full_access scope.",
            "requestBody": {
              "required": true,
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object",
                    "required": ["card_id", "pitch", "rate"],
                    "properties": {
                      "card_id": {
                        "type": "string",
                        "format": "uuid"
                      },
                      "pitch": {
                        "type": "string"
                      },
                      "rate": {
                        "type": "number",
                        "description": "Proposed numeric rate"
                      }
                    }
                  }
                }
              }
            },
            "responses": {
              "200": {
                "description": "Success"
              }
            }
          }
        }
      },
      "components": {
        "securitySchemes": {
          "BearerAuth": {
            "type": "http",
            "scheme": "bearer"
          }
        }
      },
      "security": [
        {
          "BearerAuth": []
        }
      ]
    };

    final instructionPack = '''
You are an AI assistant helping me with my account on the Promo app.
To connect, configure your network tool/custom action using these details:

- API Gateway URL: $gatewayUrl
- Authorization Header: Bearer $rawKey

Here is the OpenAPI Schema you need to register to communicate with the app gateway:
${const JsonEncoder.withIndent('  ').convert(openApiSpec)}
''';

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Iconsax.cpu, color: AppColors.accent, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'AI Agent Key Generated',
                      style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Copy the setup instructions below. For safety, this key is hashed in our database and cannot be retrieved again after closing this panel.',
                  style: TextStyle(fontSize: 13, height: 1.45),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          rawKey,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Iconsax.copy, size: 18, color: AppColors.accent),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: rawKey));
                          AppSnackbar.success(context, 'Key token copied to clipboard!');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: instructionPack));
                      AppSnackbar.success(context, 'ChatGPT setup pack copied to clipboard!');
                    },
                    icon: const Icon(Iconsax.document_copy, size: 18),
                    label: const Text('Copy ChatGPT Instructions & OpenAPI Schema'),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCreateBottomSheet() {
    _keyNameCtrl.clear();
    setState(() {
      _selectedExpiry = '7_days';
      _scopeReadOnly = true;
      _scopeFullAccess = false;
    });

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Iconsax.cpu_setting, color: AppColors.accent, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'Create AI Agent Key',
                          style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _keyNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Key Label / Name',
                        hintText: 'e.g., My ChatGPT Integration',
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedExpiry,
                      decoration: const InputDecoration(labelText: 'Expiration Period'),
                      items: const [
                        DropdownMenuItem(value: '24_hours', child: Text('24 Hours')),
                        DropdownMenuItem(value: '7_days', child: Text('7 Days')),
                        DropdownMenuItem(value: '30_days', child: Text('30 Days')),
                        DropdownMenuItem(value: 'never', child: Text('Never (No Expiration)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => _selectedExpiry = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('Permissions / Scopes', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      title: const Text('Read Only (Recommended)'),
                      subtitle: const Text('Allows AI to fetch cards, chats, and application history'),
                      value: _scopeReadOnly,
                      onChanged: (val) {
                        setSheetState(() {
                          _scopeReadOnly = val ?? true;
                          if (!_scopeReadOnly && !_scopeFullAccess) {
                            _scopeReadOnly = true; // Block unchecking both
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      title: const Text('Full Access'),
                      subtitle: const Text('Allows AI to submit campaign applications and pitches'),
                      value: _scopeFullAccess,
                      onChanged: (val) {
                        setSheetState(() {
                          _scopeFullAccess = val ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(sheetCtx),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final name = _keyNameCtrl.text.trim();
                              if (name.isNotEmpty) {
                                Navigator.pop(sheetCtx);
                                _createMcpKey(name);
                              }
                            },
                            child: const Text('Generate Key'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Agent (MCP) Keys'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Active Agent Connection Keys', style: AppTextStyles.overline),
                      ElevatedButton.icon(
                        onPressed: _saving ? null : _showCreateBottomSheet,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('New Key'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.accentOnDark,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _keys.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Iconsax.cpu, size: 48, color: Colors.grey),
                                SizedBox(height: 12),
                                Text(
                                  'No AI Agent integration keys found.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _keys.length,
                            separatorBuilder: (_, index) => const SizedBox(height: 12),
                            itemBuilder: (context, idx) {
                              final keyObj = _keys[idx];
                              final keyId = keyObj['id'] as String;
                              final keyName = keyObj['name'] as String? ?? 'Agent Key';
                              final createdDate = keyObj['created_at'] != null
                                  ? DateFormat('MMM d, yyyy').format(DateTime.parse(keyObj['created_at']))
                                  : 'Unknown';
                              final scopesList = List<dynamic>.from(keyObj['scopes'] ?? []);
                              final isFullAccess = scopesList.contains('full_access');

                              return Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isFullAccess ? Iconsax.cpu_setting : Iconsax.cpu,
                                      color: isFullAccess ? Colors.orange : AppColors.accent,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            keyName,
                                            style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Created on: $createdDate • Scope: ${isFullAccess ? "Full Access" : "Read Only"}',
                                            style: AppTextStyles.captionSm.copyWith(color: AppColors.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Iconsax.trash, color: Colors.red, size: 20),
                                      onPressed: () async {
                                        final confirmed = await showPremiumConfirmDialog(
                                          context: context,
                                          title: 'Revoke Agent Key',
                                          message: 'Are you sure you want to revoke this AI key? ChatGPT will immediately lose access to your account data.',
                                          confirmLabel: 'Revoke Key',
                                          isDestructive: true,
                                          icon: Iconsax.cpu,
                                        );
                                        if (confirmed == true) {
                                          _revokeKey(keyId);
                                        }
                                      },
                                    ),
                                  ],
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
