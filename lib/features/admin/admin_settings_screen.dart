import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/shared_widgets.dart';

class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : const Color(0xFFF9FAFB),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56 + AppSpacing.pageMarginVertical),
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
              'Settings',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          _SettingsSection(title: 'Account & Security', items: [
            _SettingsItem(
              icon: Iconsax.lock,
              label: 'Privacy Settings',
              onTap: () => context.push('/admin/settings/privacy'),
            ),
            _SettingsItem(
              icon: Iconsax.shield,
              label: 'Security',
              subtitle: 'Password & active sessions',
              onTap: () => context.push('/admin/settings/security'),
            ),
          ]),
          const SizedBox(height: 20),
          _SettingsSection(title: 'Preferences', items: [
            _SettingsItem(
              icon: ref.watch(themeModeProvider) == ThemeMode.system
                  ? Iconsax.mobile
                  : ref.watch(themeModeProvider) == ThemeMode.dark
                      ? Iconsax.moon
                      : Iconsax.sun_1,
              label: 'Theme Mode',
              subtitle: ref.watch(themeModeProvider) == ThemeMode.system
                  ? 'System default'
                  : ref.watch(themeModeProvider) == ThemeMode.dark
                      ? 'Dark Mode'
                      : 'Light Mode',
              onTap: () => _showThemeSelectionDialog(context, ref),
            ),
          ]),
          const SizedBox(height: 20),
          _SettingsSection(title: 'Actions', items: [
            _SettingsItem(
              icon: Iconsax.document_download,
              label: 'Export Platform Stats (PDF)',
              subtitle: 'Download investor-ready metrics',
              onTap: () => _exportPlatformStats(context),
            ),
            _SettingsItem(
              icon: Iconsax.logout,
              label: 'Sign Out',
              labelColor: Colors.red,
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Confirm Logout'),
                    content: const Text('Are you sure you want to log out of the admin console?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Logout', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(authProvider.notifier).signOut();
                }
              },
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _exportPlatformStats(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating Platform PDF Report...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final sb = SupabaseService.client;
      final futures = await Future.wait([
        sb.from('profiles').select('id').eq('role', 'brand').count(CountOption.exact),
        sb.from('profiles').select('id').eq('role', 'influencer').count(CountOption.exact),
        sb.from('profiles').select('id').eq('is_verified', true).count(CountOption.exact),
        sb.from('profile_views').select('id').count(CountOption.exact),
        sb.from('cards').select('id').eq('status', 'active').count(CountOption.exact),
        sb.from('messages').select('id').count(CountOption.exact),
      ]);

      final totalBrands = futures[0].count;
      final totalCreators = futures[1].count;
      final totalVerified = futures[2].count;
      final totalViews = futures[3].count;
      final activeCards = futures[4].count;
      final totalMessages = futures[5].count;

      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(32),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('PROMO PLATFORM REPORT', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                      pw.Text(DateFormat('yyyy-MM-dd').format(DateTime.now()), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Divider(thickness: 2),
                  pw.SizedBox(height: 20),
                  pw.Text('Executive Summary', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'This document presents the operational metrics of the Promo Platform, demonstrating brand and influencer engagement, messaging volume, campaign card activities, and profile traffic.',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.SizedBox(height: 30),
                  pw.Text('Key Performance Indicators', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 15),
                  
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      _buildTableRow('Indicator', 'Value', isHeader: true),
                      _buildTableRow('Total Brands Joined', '$totalBrands'),
                      _buildTableRow('Total Creators Joined', '$totalCreators'),
                      _buildTableRow('Total Profiles Verified', '$totalVerified'),
                      _buildTableRow('Platform Profile Views', '$totalViews'),
                      _buildTableRow('Active Campaign Cards', '$activeCards'),
                      _buildTableRow('Total Messages Exchanged', '$totalMessages'),
                    ],
                  ),
                  pw.SizedBox(height: 40),
                  pw.Text('Report generated securely via Promo Admin Panel.', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                ],
              ),
            );
          },
        ),
      );

      if (context.mounted) {
        Navigator.pop(context);
      }

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Promo_Platform_Stats_Report.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    }
  }

  pw.TableRow _buildTableRow(String label, String value, {bool isHeader = false}) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  void _showThemeSelectionDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Theme Mode'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              ref.read(themeModeProvider.notifier).state = ThemeMode.system;
              Navigator.pop(ctx);
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('System Default'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              ref.read(themeModeProvider.notifier).state = ThemeMode.dark;
              Navigator.pop(ctx);
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Dark Mode'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              ref.read(themeModeProvider.notifier).state = ThemeMode.light;
              Navigator.pop(ctx);
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Light Mode'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<_SettingsItem> items;

  const _SettingsSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: AppTextStyles.overline.copyWith(
            color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F0F11) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
          ),
          child: Column(
            children: List.generate(items.length, (idx) {
              final item = items[idx];
              final isLast = idx == items.length - 1;
              return Column(
                children: [
                  item,
                  if (!isLast)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFF1F5F9),
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? labelColor;

  const _SettingsItem({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: labelColor ?? AppColors.textSecondary, size: 22),
      title: Text(
        label,
        style: AppTextStyles.body.copyWith(
          fontWeight: FontWeight.bold,
          color: labelColor,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, style: AppTextStyles.caption)
          : null,
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
      onTap: onTap,
    );
  }
}
