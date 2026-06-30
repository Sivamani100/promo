import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/app_card.dart';

class AdminUserLogsScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const AdminUserLogsScreen({super.key, required this.user});

  @override
  State<AdminUserLogsScreen> createState() => _AdminUserLogsScreenState();
}

class _AdminUserLogsScreenState extends State<AdminUserLogsScreen> {
  late Map<String, dynamic> _user;
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _auditLogs = [];
  List<Map<String, dynamic>> _profileViewsVisited = [];
  List<Map<String, dynamic>> _profileViewsVisitors = [];
  List<Map<String, dynamic>> _campaigns = [];
  List<Map<String, dynamic>> _applications = [];

  @override
  void initState() {
    super.initState();
    _user = Map<String, dynamic>.from(widget.user);
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final userId = _user['id'] as String;
    final isBrand = _user['role'] == 'brand';

    try {
      final sb = SupabaseService.client;

      // 1. Reload profiles to get latest data
      final profileRes = await sb.from('profiles').select().eq('id', userId).maybeSingle();
      if (profileRes != null) {
        _user = Map<String, dynamic>.from(profileRes);
      }

      // 2. Fetch Chat Rooms
      final roomsRes = await sb
          .from('rooms')
          .select('*, brand:profiles!rooms_brand_id_fkey(*), influencer:profiles!rooms_influencer_id_fkey(*), card:cards!rooms_card_id_fkey(title)')
          .or('brand_id.eq.$userId,influencer_id.eq.$userId')
          .order('created_at', ascending: false);
      _rooms = List<Map<String, dynamic>>.from(roomsRes);

      // 3. Fetch Audit Logs
      final logsRes = await sb
          .from('audit_logs')
          .select()
          .eq('actor_id', userId)
          .order('created_at', ascending: false)
          .limit(100);
      _auditLogs = List<Map<String, dynamic>>.from(logsRes);

      // 4. Fetch Profile Views (Visited)
      try {
        final visitedRes = await sb
            .from('profile_views')
            .select('*, profile:profiles!profile_views_profile_id_fkey(*)')
            .eq('viewer_id', userId)
            .order('viewed_at', ascending: false)
            .limit(50);
        _profileViewsVisited = List<Map<String, dynamic>>.from(visitedRes);
      } catch (e) {
        debugPrint('[LOGS] Error getting profile views visited: $e');
        try {
          final visitedRes = await sb
              .from('profile_views')
              .select('*, profile:profiles(*)')
              .eq('viewer_id', userId)
              .order('viewed_at', ascending: false)
              .limit(50);
          _profileViewsVisited = List<Map<String, dynamic>>.from(visitedRes);
        } catch (e2) {
          debugPrint('[LOGS] Error getting profile views visited fallback: $e2');
        }
      }

      // 5. Fetch Profile Views (Visitors)
      try {
        final visitorsRes = await sb
            .from('profile_views')
            .select('*, viewer:profiles!profile_views_viewer_id_fkey(*)')
            .eq('profile_id', userId)
            .order('viewed_at', ascending: false)
            .limit(50);
        _profileViewsVisitors = List<Map<String, dynamic>>.from(visitorsRes);
      } catch (e) {
        debugPrint('[LOGS] Error getting profile views visitors: $e');
        try {
          final visitorsRes = await sb
              .from('profile_views')
              .select('*, viewer:profiles(*)')
              .eq('profile_id', userId)
              .order('viewed_at', ascending: false)
              .limit(50);
          _profileViewsVisitors = List<Map<String, dynamic>>.from(visitorsRes);
        } catch (e2) {
          debugPrint('[LOGS] Error getting profile views visitors fallback: $e2');
        }
      }

      // 6. Fetch Campaigns or Applications
      if (isBrand) {
        final campaignsRes = await sb
            .from('cards')
            .select('*, brand:profiles!cards_brand_id_fkey(*)')
            .eq('brand_id', userId)
            .order('created_at', ascending: false);
        _campaigns = List<Map<String, dynamic>>.from(campaignsRes);
      } else {
        final applicationsRes = await sb
            .from('applications')
            .select('*, card:cards!applications_card_id_fkey(*, brand:profiles!cards_brand_id_fkey(*))')
            .eq('influencer_id', userId)
            .order('created_at', ascending: false);
        _applications = List<Map<String, dynamic>>.from(applicationsRes);
      }

      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[LOGS SCREEN] Error loading data: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Error loading log details: $e';
        });
      }
    }
  }

  // --- REPORT GENERATION ---

  String _generateMarkdownReport() {
    final displayName = _user['display_name'] ?? 'User';
    final role = (_user['role'] as String? ?? 'unknown').toUpperCase();
    final status = (_user['account_status'] as String? ?? 'active').toUpperCase();
    final warnings = _user['warning_count'] ?? 0;
    final id = _user['id'];
    final dateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    final buffer = StringBuffer();
    buffer.writeln('# PROMO USER ACTIVITY & AUDIT REPORT');
    buffer.writeln('Report generated at: $dateStr\n');
    buffer.writeln('## PROFILE OVERVIEW');
    buffer.writeln('- **Name:** $displayName');
    buffer.writeln('- **Role:** $role');
    buffer.writeln('- **User ID:** $id');
    buffer.writeln('- **Account Status:** $status');
    buffer.writeln('- **Warning Count:** $warnings');
    buffer.writeln('- **Bio:** ${_user['bio'] ?? 'None'}');
    buffer.writeln('- **Location:** ${_user['location'] ?? 'None'}');
    buffer.writeln('\n## ENGAGEMENT SUMMARY');
    buffer.writeln('- **Total Conversations/Chats:** ${_rooms.length}');
    if (_user['role'] == 'brand') {
      buffer.writeln('- **Total Campaigns Created:** ${_campaigns.length}');
    } else {
      buffer.writeln('- **Total Applications Submitted:** ${_applications.length}');
    }
    buffer.writeln('- **Total Profiles Visited:** ${_profileViewsVisited.length}');
    buffer.writeln('- **Total Profile Visitors:** ${_profileViewsVisitors.length}');
    buffer.writeln('- **Recent Actions Tracked:** ${_auditLogs.length}');

    buffer.writeln('\n## CHAT ROOMS & CONVERSATIONS');
    if (_rooms.isEmpty) {
      buffer.writeln('*No active chat sessions found.*');
    } else {
      buffer.writeln('| Room ID | Chat Partner | Partner Role | Card (Campaign) Title | Created At |');
      buffer.writeln('| --- | --- | --- | --- | --- |');
      for (final r in _rooms) {
        final partner = _user['role'] == 'brand' ? r['influencer'] : r['brand'];
        final pName = partner?['display_name'] ?? 'Anonymous';
        final pRole = (partner?['role'] as String? ?? 'unknown').toUpperCase();
        final cTitle = r['card']?['title'] ?? 'Direct Chat';
        final cDate = r['created_at'] != null ? DateFormat('yyyy-MM-dd').format(DateTime.parse(r['created_at'])) : '';
        buffer.writeln('| ${r['id']} | $pName | $pRole | $cTitle | $cDate |');
      }
    }

    if (_user['role'] == 'brand') {
      buffer.writeln('\n## CAMPAIGNS CREATED');
      if (_campaigns.isEmpty) {
        buffer.writeln('*No campaigns found.*');
      } else {
        buffer.writeln('| Campaign ID | Title | Status | Created At |');
        buffer.writeln('| --- | --- | --- | --- |');
        for (final c in _campaigns) {
          final cDate = c['created_at'] != null ? DateFormat('yyyy-MM-dd').format(DateTime.parse(c['created_at'])) : '';
          buffer.writeln('| ${c['id']} | ${c['title'] ?? 'No Title'} | ${(c['status'] as String).toUpperCase()} | $cDate |');
        }
      }
    } else {
      buffer.writeln('\n## APPLICATIONS SUBMITTED');
      if (_applications.isEmpty) {
        buffer.writeln('*No applications found.*');
      } else {
        buffer.writeln('| Campaign Title | Brand Name | Status | Proposed Rate | Submitted At |');
        buffer.writeln('| --- | --- | --- | --- | --- |');
        for (final a in _applications) {
          final card = a['card'];
          final cTitle = card?['title'] ?? 'No Title';
          final brandName = card?['brand']?['display_name'] ?? 'Unknown Brand';
          final status = (a['status'] as String? ?? 'pending').toUpperCase();
          final rate = a['proposed_rate'] ?? 'Not Specified';
          final aDate = a['created_at'] != null ? DateFormat('yyyy-MM-dd').format(DateTime.parse(a['created_at'])) : '';
          buffer.writeln('| $cTitle | $brandName | $status | $rate | $aDate |');
        }
      }
    }

    buffer.writeln('\n## PROFILE VIEWS RECORD');
    buffer.writeln('### Profiles Visited by This User:');
    if (_profileViewsVisited.isEmpty) {
      buffer.writeln('*No visited profiles recorded.*');
    } else {
      buffer.writeln('| Profile ID | Target User | Role | Visited At |');
      buffer.writeln('| --- | --- | --- | --- |');
      for (final v in _profileViewsVisited) {
        final profile = v['profile'];
        final pName = profile?['display_name'] ?? 'Anonymous';
        final pRole = (profile?['role'] as String? ?? 'unknown').toUpperCase();
        final vDate = v['viewed_at'] != null 
            ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(v['viewed_at'])) 
            : '';
        buffer.writeln('| ${v['profile_id']} | $pName | $pRole | $vDate |');
      }
    }

    buffer.writeln('\n### Visitors to This User\'s Profile:');
    if (_profileViewsVisitors.isEmpty) {
      buffer.writeln('*No visitors recorded.*');
    } else {
      buffer.writeln('| Viewer ID | Viewer Name | Role | Visited At |');
      buffer.writeln('| --- | --- | --- | --- |');
      for (final v in _profileViewsVisitors) {
        final viewer = v['viewer'];
        final vName = viewer?['display_name'] ?? 'Anonymous';
        final vRole = (viewer?['role'] as String? ?? 'unknown').toUpperCase();
        final vDate = v['viewed_at'] != null 
            ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(v['viewed_at'])) 
            : '';
        buffer.writeln('| ${v['viewer_id'] ?? 'Anonymous'} | $vName | $vRole | $vDate |');
      }
    }

    buffer.writeln('\n## SYSTEM AUDIT & ACTIVITY LOGS');
    if (_auditLogs.isEmpty) {
      buffer.writeln('*No logs recorded in the system audit logs.*');
    } else {
      buffer.writeln('| Event ID | Action | Target Type | Metadata | Timestamp |');
      buffer.writeln('| --- | --- | --- | --- | --- |');
      for (final log in _auditLogs) {
        final action = (log['action'] as String? ?? 'event').toUpperCase().replaceAll('_', ' ');
        final tType = (log['target_type'] as String? ?? 'system').toUpperCase();
        final meta = log['metadata']?.toString() ?? 'None';
        final cDate = log['created_at'] != null 
            ? DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(log['created_at'])) 
            : '';
        buffer.writeln('| ${log['id']} | $action | $tType | $meta | $cDate |');
      }
    }

    return buffer.toString();
  }

  Future<void> _exportPdfReport() async {
    final displayName = _user['display_name'] ?? 'User';
    final role = (_user['role'] as String? ?? 'unknown').toUpperCase();
    final status = (_user['account_status'] as String? ?? 'active').toUpperCase();
    final warnings = _user['warning_count'] ?? 0;
    final id = _user['id'];
    final dateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    final doc = pw.Document();
    final font = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('PROMO - SYSTEM REPORT', style: pw.TextStyle(font: boldFont, fontSize: 18, color: PdfColors.purple)),
                  pw.Text(dateStr, style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text('User Audit & Activity Logs', style: pw.TextStyle(font: boldFont, fontSize: 24)),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 16),

            // Profile summary
            pw.Text('Profile Overview', style: pw.TextStyle(font: boldFont, fontSize: 14)),
            pw.SizedBox(height: 8),
            pw.Bullet(text: 'Display Name: $displayName', style: pw.TextStyle(font: font, fontSize: 11)),
            pw.Bullet(text: 'User ID: $id', style: pw.TextStyle(font: font, fontSize: 11)),
            pw.Bullet(text: 'Role: $role', style: pw.TextStyle(font: font, fontSize: 11)),
            pw.Bullet(text: 'Account Status: $status', style: pw.TextStyle(font: font, fontSize: 11)),
            pw.Bullet(text: 'Warning Count: $warnings', style: pw.TextStyle(font: font, fontSize: 11)),
            pw.Bullet(text: 'Bio: ${_user['bio'] ?? 'None'}', style: pw.TextStyle(font: font, fontSize: 11)),
            pw.Bullet(text: 'Location: ${_user['location'] ?? 'None'}', style: pw.TextStyle(font: font, fontSize: 11)),
            pw.SizedBox(height: 24),

            // Engagement stats
            pw.Text('Engagement Metrics', style: pw.TextStyle(font: boldFont, fontSize: 14)),
            pw.SizedBox(height: 8),
            pw.Bullet(text: 'Total Active Chat Rooms: ${_rooms.length}', style: pw.TextStyle(font: font, fontSize: 11)),
            if (_user['role'] == 'brand')
              pw.Bullet(text: 'Total Campaigns Created: ${_campaigns.length}', style: pw.TextStyle(font: font, fontSize: 11))
            else
              pw.Bullet(text: 'Total Applications Submitted: ${_applications.length}', style: pw.TextStyle(font: font, fontSize: 11)),
            pw.Bullet(text: 'Profiles Visited: ${_profileViewsVisited.length}', style: pw.TextStyle(font: font, fontSize: 11)),
            pw.Bullet(text: 'Profile Visitors: ${_profileViewsVisitors.length}', style: pw.TextStyle(font: font, fontSize: 11)),
            pw.Bullet(text: 'Audit Logs Registered: ${_auditLogs.length}', style: pw.TextStyle(font: font, fontSize: 11)),
            pw.SizedBox(height: 24),
          ];
        },
      ),
    );

    // Add chat detail page if there are rooms
    if (_rooms.isNotEmpty) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Text('Chat Conversations Logs', style: pw.TextStyle(font: boldFont, fontSize: 16)),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                context: context,
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(font: boldFont, fontSize: 10),
                cellStyle: pw.TextStyle(font: font, fontSize: 9),
                headers: ['Room ID', 'Partner Name', 'Partner Role', 'Campaign (Card) Title', 'Created At'],
                data: _rooms.map((r) {
                  final partner = _user['role'] == 'brand' ? r['influencer'] : r['brand'];
                  final pName = partner?['display_name'] ?? 'Anonymous';
                  final pRole = (partner?['role'] as String? ?? 'unknown').toUpperCase();
                  final cTitle = r['card']?['title'] ?? 'Direct Chat';
                  final cDate = r['created_at'] != null ? DateFormat('yyyy-MM-dd').format(DateTime.parse(r['created_at'])) : '';
                  return ['${r['id'].toString().substring(0, 8)}...', pName, pRole, cTitle, cDate];
                }).toList(),
              ),
            ];
          },
        ),
      );
    }

    // Add audit logs pages
    if (_auditLogs.isNotEmpty) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Text('Recent Audit & Activity Logs', style: pw.TextStyle(font: boldFont, fontSize: 16)),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                context: context,
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(font: boldFont, fontSize: 9),
                cellStyle: pw.TextStyle(font: font, fontSize: 8),
                headers: ['Action', 'Target Type', 'Metadata Detail', 'Timestamp'],
                data: _auditLogs.take(25).map((log) {
                  final action = (log['action'] as String? ?? 'event').toUpperCase().replaceAll('_', ' ');
                  final tType = (log['target_type'] as String? ?? 'system').toUpperCase();
                  final meta = log['metadata']?.toString() ?? 'None';
                  final cDate = log['created_at'] != null 
                      ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(log['created_at'])) 
                      : '';
                  return [action, tType, meta.length > 50 ? '${meta.substring(0, 47)}...' : meta, cDate];
                }).toList(),
              ),
            ];
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'report_${_user['role']}_${_user['display_name']}.pdf',
    );
  }

  void _shareMarkdownSummary() {
    final report = _generateMarkdownReport();
    final displayName = _user['display_name'] ?? 'User';
    Share.share(
      report,
      subject: 'Activity Report - $displayName',
    );
  }

  // --- WIDGET BUILD ---

  Widget _buildOverviewTab(BuildContext context, bool isDark) {
    final displayName = _user['display_name'] ?? 'User';
    final role = _user['role'] as String? ?? 'influencer';
    final status = _user['account_status'] as String? ?? 'active';
    final warnings = _user['warning_count'] ?? 0;
    
    Color statusColor = Colors.green;
    if (status == 'banned') {
      statusColor = Colors.red;
    } else if (status == 'suspended') {
      statusColor = Colors.orange;
    } else if (status == 'warned') {
      statusColor = Colors.yellow.shade700;
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User Card Header
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                AppAvatar(
                  url: _user['avatar_url'],
                  fallbackText: displayName,
                  size: 70,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_user['is_verified'] == true) ...[
                            const SizedBox(width: 6),
                            const VerificationBadge(size: 18),
                          ]
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        role.toUpperCase(),
                        style: AppTextStyles.label.copyWith(color: AppColors.purple, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                          ),
                          const SizedBox(width: 6),
                          Text(status.toUpperCase(), style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 12),
                          const Icon(Iconsax.info_circle, size: 14, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text('$warnings Warnings', style: AppTextStyles.caption.copyWith(color: Colors.orange)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: 0.1, end: 0),
          const SizedBox(height: 16),

          // Bento Box Counts Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _buildStatsBox('TOTAL CHATS', '${_rooms.length}', Iconsax.messages, Colors.blue),
              if (role == 'brand')
                _buildStatsBox('CAMPAIGNS', '${_campaigns.length}', Iconsax.note_2, Colors.purple)
              else
                _buildStatsBox('APPLICATIONS', '${_applications.length}', Iconsax.task, Colors.purple),
              _buildStatsBox('PROFILES VISITED', '${_profileViewsVisited.length}', Iconsax.eye, Colors.teal),
              _buildStatsBox('PROFILE VISITORS', '${_profileViewsVisitors.length}', Iconsax.user_tag, Colors.amber),
            ],
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 24),

          // Download and Export buttons
          Text('REPORT EXPORT ACTIONS', style: AppTextStyles.overline),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _exportPdfReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Iconsax.document_download),
                  label: const Text('Export PDF Report', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareMarkdownSummary,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.purple,
                    side: BorderSide(color: AppColors.purple),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Iconsax.share),
                  label: const Text('Share Text Log', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 24),

          // Details List
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User Bio', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(_user['bio'] ?? 'No bio description provided.', style: AppTextStyles.body),
                const Divider(height: 24),
                Text('User Details', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildDetailRow('Location', _user['location'] ?? 'Not Specified'),
                _buildDetailRow('Created At', _user['created_at'] != null ? DateFormat('MMM dd, yyyy h:mm a').format(DateTime.parse(_user['created_at'])) : 'Unknown'),
                _buildDetailRow('User UUID', _user['id']),
                _buildDetailRow('AB Variant', _user['ab_variant'] ?? 'A'),
              ],
            ),
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),
        ],
      ),
    );
  }

  Widget _buildStatsBox(String title, String val, IconData icon, Color color) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTextStyles.overline.copyWith(fontSize: 9),
              ),
              Icon(icon, size: 18, color: color),
            ],
          ),
          Text(
            val,
            style: AppTextStyles.h1.copyWith(fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(value, style: AppTextStyles.caption),
          ),
        ],
      ),
    );
  }

  Widget _buildChatsTab() {
    if (_rooms.isEmpty) {
      return const AppEmptyState(icon: Iconsax.message, title: 'No chat sessions found for this user');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _rooms.length,
      itemBuilder: (context, index) {
        final room = _rooms[index];
        final isBrand = _user['role'] == 'brand';
        final partner = isBrand ? room['influencer'] : room['brand'];
        final partnerName = partner?['display_name'] ?? 'Anonymous';
        final partnerRole = (partner?['role'] as String? ?? 'unknown').toUpperCase();
        final campaignTitle = room['card']?['title'] ?? 'Direct Messages';
        
        final createdAt = room['created_at'] != null 
            ? DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(room['created_at'])) 
            : 'Unknown';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            onTap: () {
              // Navigating to the room
              context.push('/admin/chats/${room['id']}');
            },
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                AppAvatar(
                  url: partner?['avatar_url'],
                  fallbackText: partnerName,
                  size: 46,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              partnerName,
                              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            partnerRole,
                            style: AppTextStyles.captionSm.copyWith(color: AppColors.purple, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Campaign: $campaignTitle',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Opened: $createdAt',
                        style: AppTextStyles.captionSm.copyWith(color: AppColors.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const Icon(Iconsax.arrow_right_3, size: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivitiesTab() {
    if (_auditLogs.isEmpty) {
      return const AppEmptyState(icon: Iconsax.document_text, title: 'No recorded system activity logs');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _auditLogs.length,
      itemBuilder: (context, index) {
        final log = _auditLogs[index];
        final action = (log['action'] as String? ?? 'event').toUpperCase().replaceAll('_', ' ');
        final targetType = (log['target_type'] as String? ?? 'system').toUpperCase();
        final metadata = log['metadata'];
        final createdAt = log['created_at'] != null 
            ? DateFormat('MMM d, yyyy h:mm:ss a').format(DateTime.parse(log['created_at'])) 
            : 'Unknown';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      action,
                      style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold, color: AppColors.purple),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        targetType,
                        style: AppTextStyles.overline.copyWith(color: AppColors.accent, fontSize: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (metadata != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? const Color(0xFF1E1E24) 
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      metadata.toString(),
                      style: AppTextStyles.caption.copyWith(fontFamily: 'monospace', fontSize: 10),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  createdAt,
                  style: AppTextStyles.captionSm.copyWith(color: AppColors.textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildViewsTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Profiles Visited'),
              Tab(text: 'Profile Visitors'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildProfileViewsList(_profileViewsVisited, isVisited: true),
                _buildProfileViewsList(_profileViewsVisitors, isVisited: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileViewsList(List<Map<String, dynamic>> viewsList, {required bool isVisited}) {
    if (viewsList.isEmpty) {
      return AppEmptyState(
        icon: Iconsax.eye, 
        title: isVisited ? 'No visited profiles logs' : 'No profile visitors logs',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: viewsList.length,
      itemBuilder: (context, index) {
        final v = viewsList[index];
        final profileMap = isVisited ? v['profile'] : v['viewer'];
        final pName = profileMap?['display_name'] ?? 'Anonymous';
        final pRole = (profileMap?['role'] as String? ?? 'unknown').toUpperCase();
        
        final viewedAt = v['viewed_at'] != null 
            ? DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(v['viewed_at'])) 
            : 'Unknown';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                AppAvatar(
                  url: profileMap?['avatar_url'],
                  fallbackText: pName,
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
                              pName,
                              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            pRole,
                            style: AppTextStyles.captionSm.copyWith(color: AppColors.purple, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Viewed: $viewedAt',
                        style: AppTextStyles.captionSm.copyWith(color: AppColors.textMuted, fontSize: 10),
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

  Widget _buildCampaignsOrApplicationsTab() {
    final isBrand = _user['role'] == 'brand';

    if (isBrand) {
      if (_campaigns.isEmpty) {
        return const AppEmptyState(icon: Iconsax.note_2, title: 'No campaigns created by this brand');
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _campaigns.length,
        itemBuilder: (context, index) {
          final c = _campaigns[index];
          final title = c['title'] ?? 'No Title';
          final status = (c['status'] as String? ?? 'active').toUpperCase();
          final createdAt = c['created_at'] != null 
              ? DateFormat('MMM d, yyyy').format(DateTime.parse(c['created_at'])) 
              : 'Unknown';

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text('Created: $createdAt', style: AppTextStyles.captionSm.copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: status == 'ACTIVE' ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status,
                      style: AppTextStyles.captionSm.copyWith(
                        color: status == 'ACTIVE' ? Colors.green : Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      if (_applications.isEmpty) {
        return const AppEmptyState(icon: Iconsax.task, title: 'No campaign applications submitted by this influencer');
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _applications.length,
        itemBuilder: (context, index) {
          final a = _applications[index];
          final card = a['card'];
          final cTitle = card?['title'] ?? 'No Title';
          final brandName = card?['brand']?['display_name'] ?? 'Unknown Brand';
          final status = (a['status'] as String? ?? 'pending').toUpperCase();
          final rate = a['proposed_rate'] ?? 'Not Specified';
          
          final createdAt = a['created_at'] != null 
              ? DateFormat('MMM d, yyyy').format(DateTime.parse(a['created_at'])) 
              : 'Unknown';

          Color statusCol = Colors.orange;
          if (status == 'ACCEPTED') {
            statusCol = Colors.green;
          } else if (status == 'REJECTED') {
            statusCol = Colors.red;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          cTitle,
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusCol.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status,
                          style: AppTextStyles.overline.copyWith(color: statusCol, fontWeight: FontWeight.bold, fontSize: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Brand: $brandName', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                      Text('Rate: $rate', style: AppTextStyles.captionSm.copyWith(color: AppColors.purple, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 16),
                  if (a['pitch_message'] != null && (a['pitch_message'] as String).trim().isNotEmpty) ...[
                    Text('Pitch Message:', style: AppTextStyles.captionSm.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(a['pitch_message'], style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic)),
                    const SizedBox(height: 6),
                  ],
                  Text('Applied on: $createdAt', style: AppTextStyles.captionSm.copyWith(color: AppColors.textMuted, fontSize: 9)),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayName = _user['display_name'] ?? 'User';

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.background : const Color(0xFFF9FAFB),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(104 + AppSpacing.pageMarginVertical),
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.appBarMarginHorizontal,
              right: AppSpacing.appBarMarginHorizontal,
              top: AppSpacing.pageMarginVertical,
            ),
            child: AppBar(
              centerTitle: false,
              titleSpacing: 0,
              leading: IconButton(
                icon: const Icon(Iconsax.arrow_left),
                onPressed: () => context.pop(),
              ),
              title: Text(
                'Logs: $displayName',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              actions: [
                IconButton(
                  icon: const Icon(Iconsax.refresh, size: 20),
                  onPressed: _loadData,
                ),
              ],
              bottom: TabBar(
                isScrollable: true,
                labelColor: AppColors.purple,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.purple,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                tabs: [
                  const Tab(text: 'OVERVIEW'),
                  const Tab(text: 'CHATS'),
                  const Tab(text: 'ACTIVITIES'),
                  const Tab(text: 'VIEWS'),
                  Tab(text: (_user['role'] == 'brand' ? 'CAMPAIGNS' : 'APPLICATIONS')),
                ],
              ),
            ),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Iconsax.danger, color: Colors.red, size: 40),
                          const SizedBox(height: 12),
                          Text(_error!, style: AppTextStyles.body, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadData,
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  )
                : TabBarView(
                    children: [
                      _buildOverviewTab(context, isDark),
                      _buildChatsTab(),
                      _buildActivitiesTab(),
                      _buildViewsTab(),
                      _buildCampaignsOrApplicationsTab(),
                    ],
                  ),
      ),
    );
  }
}
