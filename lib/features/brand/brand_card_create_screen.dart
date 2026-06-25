import 'package:flutter/material.dart';
import '../../shared/widgets/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/card_service.dart';
import '../../core/services/data_services.dart';
import '../../shared/widgets/shared_widgets.dart';

const _categories = ['Fashion', 'Tech', 'Food', 'Fitness', 'Beauty', 'Travel', 'Gaming', 'Lifestyle'];
const _platforms = ['Instagram', 'YouTube', 'TikTok', 'Twitter/X', 'LinkedIn'];
const _locations = ['Anywhere', 'India', 'United States', 'United Kingdom', 'Canada', 'Australia', 'Europe'];

const _presetCovers = [
  {
    'name': 'Fashion & Lifestyle',
    'url': 'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=600&auto=format&fit=crop&q=80',
  },
  {
    'name': 'Tech & Gadgets',
    'url': 'https://images.unsplash.com/photo-1468495244123-6c6c332eeece?w=600&auto=format&fit=crop&q=80',
  },
  {
    'name': 'Food & Dining',
    'url': 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&auto=format&fit=crop&q=80',
  },
  {
    'name': 'Travel & Adventure',
    'url': 'https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=600&auto=format&fit=crop&q=80',
  },
  {
    'name': 'Fitness & Sports',
    'url': 'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?w=600&auto=format&fit=crop&q=80',
  },
  {
    'name': 'Gaming & Esports',
    'url': 'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?w=600&auto=format&fit=crop&q=80',
  },
];

const _followerTiers = [
  {'label': 'Any tier', 'value': 0},
  {'label': '10k+ followers', 'value': 10000},
  {'label': '50k+ followers', 'value': 50000},
  {'label': '100k+ followers', 'value': 100000},
  {'label': '500k+ followers', 'value': 500000},
];

class BrandCardCreateScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? card;
  const BrandCardCreateScreen({super.key, this.card});
  @override
  ConsumerState<BrandCardCreateScreen> createState() => _BrandCardCreateScreenState();
}

class _BrandCardCreateScreenState extends ConsumerState<BrandCardCreateScreen> {
  int _currentStep = 0;
  bool _loading = false;

  // Controllers
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _timelineCtrl = TextEditingController();
  final _openingsCtrl = TextEditingController(text: '1');
  final _customCoverUrlCtrl = TextEditingController();

  // State
  String _category = 'Fashion';
  String _campaignType = 'Sponsored Post';
  final List<String> _nicheTags = [];
  final List<String> _platformReqs = [];
  int _minFollowers = 0;
  String _preferredLocation = 'Anywhere';
  final List<Map<String, dynamic>> _deliverables = [];
  DateTime? _applicationDeadline;
  int _selectedCoverIndex = 0;
  String _coverImageUrl = _presetCovers[0]['url']!;
  bool _uploadingCover = false;
  String? _uploadedCoverUrl;

  // Temp deliverable builder fields
  String _tempDelivType = 'Instagram Reel';
  final _tempDelivCountCtrl = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    if (widget.card != null) {
      final c = widget.card!;
      _titleCtrl.text = c['title'] ?? '';
      _descCtrl.text = c['description'] ?? '';
      _budgetCtrl.text = c['budget_range'] ?? '';
      _timelineCtrl.text = c['timeline'] ?? '';
      _openingsCtrl.text = (c['openings'] ?? 1).toString();
      _category = c['category'] ?? 'Fashion';
      _minFollowers = c['min_followers'] ?? 0;
      _preferredLocation = c['preferred_location'] ?? 'Anywhere';
      
      if (c['application_deadline'] != null) {
        _applicationDeadline = DateTime.tryParse(c['application_deadline']);
      }

      _nicheTags.addAll((c['niche_tags'] as List?)?.cast<String>() ?? []);
      _platformReqs.addAll((c['platform_requirements'] as List?)?.cast<String>() ?? []);
      
      // Cover image logic
      final savedCoverUrl = c['cover_image_url'] as String?;
      if (savedCoverUrl != null && savedCoverUrl.isNotEmpty) {
        _coverImageUrl = savedCoverUrl;
        final presetIdx = _presetCovers.indexWhere((cover) => cover['url'] == savedCoverUrl);
        if (presetIdx != -1) {
          _selectedCoverIndex = presetIdx;
        } else {
          _selectedCoverIndex = -2;
          _uploadedCoverUrl = savedCoverUrl;
          _customCoverUrlCtrl.text = savedCoverUrl;
        }
      }

      // Deliverables parsing
      final savedDeliverables = c['deliverables'] as List?;
      if (savedDeliverables != null) {
        for (final d in savedDeliverables) {
          final str = d.toString();
          final firstSpace = str.indexOf(' ');
          if (firstSpace != -1) {
            final countStr = str.substring(0, firstSpace);
            final typeStr = str.substring(firstSpace + 1);
            final count = int.tryParse(countStr) ?? 1;
            _deliverables.add({'type': typeStr, 'count': count});
          } else {
            _deliverables.add({'type': str, 'count': 1});
          }
        }
      }

      // Campaign type from niche tags or default
      if (_nicheTags.contains('Sponsored Post')) {
        _campaignType = 'Sponsored Post';
      } else if (_nicheTags.contains('Product Review')) {
        _campaignType = 'Product Review';
      } else if (_nicheTags.contains('Brand Ambassador')) {
        _campaignType = 'Brand Ambassador';
      } else if (_nicheTags.contains('Affiliate / Commission')) {
        _campaignType = 'Affiliate / Commission';
      }
    } else {
      _deliverables.add({'type': 'Instagram Reel', 'count': 1});
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _budgetCtrl.dispose();
    _timelineCtrl.dispose();
    _openingsCtrl.dispose();
    _customCoverUrlCtrl.dispose();
    _tempDelivCountCtrl.dispose();
    super.dispose();
  }

  bool _hasUnsavedChanges() {
    if (widget.card != null) {
      final c = widget.card!;
      return _titleCtrl.text != (c['title'] ?? '') ||
             _descCtrl.text != (c['description'] ?? '') ||
             _category != (c['category'] ?? 'Fashion') ||
             _budgetCtrl.text != (c['budget_range'] ?? '') ||
             _timelineCtrl.text != (c['timeline'] ?? '');
    } else {
      return _titleCtrl.text.isNotEmpty || _descCtrl.text.isNotEmpty;
    }
  }

  Future<void> _selectImageSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Upload Campaign Cover',
                style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: Icon(Iconsax.camera, color: AppColors.accent),
              title: const Text('Take Photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Iconsax.image, color: AppColors.accent),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (source != null) {
      _pickAndUploadCover(source);
    }
  }

  Future<void> _pickAndUploadCover(ImageSource source) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: source, imageQuality: 80);
      if (image == null) return;

      setState(() {
        _uploadingCover = true;
      });

      final bytes = await image.readAsBytes();
      final fileExt = image.name.split('.').last.toLowerCase();
      final cleanExt = ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(fileExt) ? fileExt : 'jpg';
      final fileName = 'cover_${DateTime.now().microsecondsSinceEpoch}.$cleanExt';
      final path = '${user.id}/$fileName';

      final publicUrl = await StorageService().uploadFile(
        'card-covers',
        path,
        bytes,
        'image/$cleanExt',
      );

      setState(() {
        _uploadedCoverUrl = publicUrl;
        _coverImageUrl = publicUrl;
        _selectedCoverIndex = -2;
        _customCoverUrlCtrl.text = publicUrl;
        _uploadingCover = false;
      });

      if (mounted) {
        AppSnackbar.show(context, 'Cover image uploaded successfully!');
      }
    } catch (e) {
      print('Error picking/uploading cover image: $e');
      if (mounted) {
        setState(() {
          _uploadingCover = false;
        });
        AppSnackbar.show(context, 'Failed to upload image: $e');
      }
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      AppSnackbar.show(context, 'Please fill in title and description.');
      return;
    }

    setState(() => _loading = true);
    try {
      final user = ref.read(authProvider).user!;
      
      // Combine campaign type and custom niche tags
      final finalNicheTags = <String>{_category, _campaignType};
      for (final t in _nicheTags) {
        if (t != _category && t != _campaignType) {
          finalNicheTags.add(t);
        }
      }

      // Format deliverables
      final deliverablesList = _deliverables.map((d) => '${d['count']} ${d['type']}').toList();

      final cardData = {
        'brand_id': user.id,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category': _category,
        'niche_tags': finalNicheTags.toList(),
        'platform_requirements': _platformReqs.isEmpty ? null : _platformReqs,
        'min_followers': _minFollowers,
        'preferred_location': _preferredLocation,
        'budget_range': _budgetCtrl.text.trim().isEmpty ? null : _budgetCtrl.text.trim(),
        'timeline': _timelineCtrl.text.trim().isEmpty ? null : _timelineCtrl.text.trim(),
        'deliverables': deliverablesList.isEmpty ? null : deliverablesList,
        'cover_image_url': _coverImageUrl,
        'application_deadline': _applicationDeadline?.toIso8601String(),
        'openings': int.tryParse(_openingsCtrl.text) ?? 1,
        'status': widget.card != null ? widget.card!['status'] : 'active',
      };

      if (widget.card != null) {
        await CardService().updateCard(widget.card!['id'], cardData);
        if (mounted) {
          AppSnackbar.show(context, 'Campaign card updated successfully!');
          context.pop(true);
        }
      } else {
        await CardService().createCard(cardData);
        if (mounted) {
          AppSnackbar.show(context, 'Campaign card published successfully!');
          context.pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, 'Failed to save card: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_titleCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
        AppSnackbar.show(context, 'Please fill in title and description.');
        return;
      }
    }
    setState(() => _currentStep++);
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.card != null;
    final theme = Theme.of(context);
    final localTheme = theme.copyWith(
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.textPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );

    return Theme(
      data: localTheme,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          if (_loading) {
            Navigator.of(context).pop(result);
            return;
          }
          if (_hasUnsavedChanges()) {
            final confirm = await showPremiumConfirmDialog(
              context: context,
              title: 'Discard Changes',
              message: 'You have unsaved changes. Are you sure you want to discard them and exit?',
              confirmLabel: 'Discard',
              isDestructive: true,
            );
            if (confirm == true && mounted) {
              Navigator.of(context).pop(result);
            }
          } else {
            Navigator.of(context).pop(result);
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(isEditing ? 'Edit Campaign Card' : 'Create Campaign Card'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () {
                Navigator.of(context).maybePop();
              },
            ),
          ),
          body: Column(
            children: [
              // Stepper indicator
              _buildStepperHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildCurrentStepView(),
                  ),
                ),
              ),
              _buildNavigationRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepperHeader() {
    const stepsCount = 4;
    final isDark = AppColors.isDarkMode;
    final activeColor = AppColors.accent;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(stepsCount * 2 - 1, (idx) {
          if (idx.isOdd) {
            // Line connector
            final stepIndex = idx ~/ 2;
            final isLineCompleted = _currentStep > stepIndex;
            return Container(
              width: 50,
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: isLineCompleted ? activeColor : (isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB)),
            );
          }

          final stepIndex = idx ~/ 2;
          final isActive = _currentStep == stepIndex;
          final isCompleted = _currentStep > stepIndex;

          Widget circleWidget;
          if (isCompleted) {
            circleWidget = Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: activeColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 16,
              ),
            );
          } else if (isActive) {
            circleWidget = Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: activeColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '${stepIndex + 1}',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          } else {
            circleWidget = Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFE5E7EB),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '${stepIndex + 1}',
                style: GoogleFonts.inter(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }

          return circleWidget;
        }),
      ),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 0:
        return _buildStepDetails();
      case 1:
        return _buildStepTargeting();
      case 2:
        return _buildStepBudget();
      case 3:
        return _buildStepPreview();
      default:
        return const SizedBox();
    }
  }

  Widget _buildStepDetails() {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Basic Campaign Details', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        AppTextField(label: 'Campaign Title', hint: 'e.g. Summer Fitness Kickoff', controller: _titleCtrl),
        const SizedBox(height: 16),
        AppTextField(label: 'Description', hint: 'Describe the campaign goals, target audience, and collaboration details...', controller: _descCtrl, maxLines: 5),
        const SizedBox(height: 16),
        Text('CAMPAIGN TYPE', style: AppTextStyles.overline),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _campaignType,
          decoration: const InputDecoration(
            hintText: 'Select Campaign Type',
          ),
          dropdownColor: AppColors.surface,
          items: ['Sponsored Post', 'Product Review', 'Brand Ambassador', 'Affiliate / Commission', 'Other']
              .map((type) => DropdownMenuItem(value: type, child: Text(type, style: AppTextStyles.body)))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _campaignType = val);
          },
        ),
        const SizedBox(height: 16),
        Text('PRIMARY CATEGORY', style: AppTextStyles.overline),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((c) {
            final isSelected = _category == c;
            return AppChip(
              label: c,
              selected: isSelected,
              color: isSelected ? AppColors.getCategoryColor(c) : null,
              onTap: () => setState(() => _category = c),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        Text('CAMPAIGN COVER IMAGE', style: AppTextStyles.overline),
        const SizedBox(height: 8),
        Builder(
          builder: (context) {
            final coverItems = <Map<String, dynamic>>[];
            
            // 1. Upload item
            coverItems.add({
              'type': 'upload',
              'name': 'Upload Cover',
            });
            
            // 2. Custom uploaded cover item (if exists)
            if (_uploadedCoverUrl != null && _uploadedCoverUrl!.trim().isNotEmpty) {
              coverItems.add({
                'type': 'uploaded',
                'url': _uploadedCoverUrl!,
                'name': 'Custom Upload',
              });
            }
            
            // 3. Preset items
            for (int i = 0; i < _presetCovers.length; i++) {
              coverItems.add({
                'type': 'preset',
                'index': i,
                'url': _presetCovers[i]['url']!,
                'name': _presetCovers[i]['name']!,
              });
            }

            return SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: coverItems.length,
                itemBuilder: (context, idx) {
                  final item = coverItems[idx];
                  final type = item['type'] as String;

                  if (type == 'upload') {
                    return GestureDetector(
                      onTap: _uploadingCover ? null : _selectImageSource,
                      child: Container(
                        width: 130,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _uploadingCover ? AppColors.accent : AppColors.border,
                            width: 1.2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: _uploadingCover
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Uploading...',
                                    style: AppTextStyles.captionSm.copyWith(color: AppColors.accent),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Iconsax.image, color: AppColors.textMuted, size: 22),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Upload Cover',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textMuted,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                      ),
                    );
                  }

                  final isSelected = type == 'uploaded'
                      ? _selectedCoverIndex == -2
                      : _selectedCoverIndex == item['index'];
                  final url = item['url'] as String;
                  final name = item['name'] as String;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (type == 'uploaded') {
                          _selectedCoverIndex = -2;
                          _coverImageUrl = url;
                          _customCoverUrlCtrl.text = url;
                        } else {
                          _selectedCoverIndex = item['index'] as int;
                          _coverImageUrl = url;
                        }
                      });
                    },
                    child: Container(
                      width: 130,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.accent : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AppImage(
                            url: url,
                            fit: BoxFit.cover,
                          ),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.1),
                                    Colors.black.withValues(alpha: 0.75),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 8,
                            right: 8,
                            bottom: 8,
                            child: Text(
                              name,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  color: AppColors.accentOnDark,
                                  size: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          }
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Or Custom Image URL',
          hint: 'Paste cover photo link...',
          controller: _customCoverUrlCtrl,
          onChanged: (val) {
            setState(() {
              _selectedCoverIndex = -1;
              _coverImageUrl = val.trim().isNotEmpty
                  ? val.trim()
                  : _presetCovers[0]['url']!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildStepTargeting() {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Targeting & Requirements', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Text('PLATFORM REQUIREMENTS', style: AppTextStyles.overline),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _platforms.map((p) {
            final isSelected = _platformReqs.contains(p);
            return AppChip(
              label: p,
              selected: isSelected,
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _platformReqs.remove(p);
                  } else {
                    _platformReqs.add(p);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Text('MINIMUM FOLLOWER REQUIREMENT', style: AppTextStyles.overline),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _followerTiers.map((tier) {
            final label = tier['label'] as String;
            final val = tier['value'] as int;
            final isSelected = _minFollowers == val;
            return AppChip(
              label: label,
              selected: isSelected,
              color: isSelected ? AppColors.accent : null,
              onTap: () => setState(() => _minFollowers = val),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Text('PREFERRED LOCATION', style: AppTextStyles.overline),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _preferredLocation,
          decoration: const InputDecoration(
            hintText: 'Select Preferred Location',
          ),
          dropdownColor: AppColors.surface,
          items: _locations
              .map((loc) => DropdownMenuItem(value: loc, child: Text(loc, style: AppTextStyles.body)))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _preferredLocation = val);
          },
        ),
        const SizedBox(height: 16),
        Text('NICHE TAGS (SELECT TO ADD OR CHOOSE CATEGORIES)', style: AppTextStyles.overline),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _categories.map((n) {
            final isSelected = _nicheTags.contains(n);
            return AppChip(
              label: '#$n',
              selected: isSelected,
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _nicheTags.remove(n);
                  } else {
                    _nicheTags.add(n);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStepBudget() {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Logistics & Deliverables', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        AppTextField(label: 'Budget / Collaboration Terms', hint: 'e.g. ₹20,000 - ₹40,000 or Product Exchange', controller: _budgetCtrl),
        const SizedBox(height: 16),
        AppTextField(label: 'Campaign Duration / Timeline', hint: 'e.g. 3 weeks from receipt of product', controller: _timelineCtrl),
        const SizedBox(height: 16),
        AppTextField(label: 'Number of Openings / Positions', hint: 'e.g. 5 creators wanted', controller: _openingsCtrl, keyboardType: TextInputType.number),
        const SizedBox(height: 16),
        Text('APPLICATION DEADLINE', style: AppTextStyles.overline),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _applicationDeadline ?? DateTime.now().add(const Duration(days: 14)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 180)),
            );
            if (date != null) {
              setState(() => _applicationDeadline = date);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _applicationDeadline == null
                      ? 'Select deadline date...'
                      : DateFormat('MMMM dd, yyyy').format(_applicationDeadline!),
                  style: AppTextStyles.body.copyWith(
                    color: _applicationDeadline == null ? AppColors.textMuted : AppColors.textPrimary,
                  ),
                ),
                Icon(Iconsax.calendar_1, size: 20, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('DELIVERABLES', style: AppTextStyles.overline),
        const SizedBox(height: 8),
        
        // Deliverables builder
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              if (_deliverables.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text('No deliverables added yet. Add at least one.', style: AppTextStyles.captionSm.copyWith(fontStyle: FontStyle.italic)),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _deliverables.length,
                  itemBuilder: (context, idx) {
                    final d = _deliverables[idx];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${d['count']}x ${d['type']}',
                              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.remove_circle_outline_rounded, color: AppColors.error, size: 18),
                            onPressed: () {
                              setState(() => _deliverables.removeAt(idx));
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const Divider(height: 20),
              
              // Add deliverable row
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _tempDelivType,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.textPrimary, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      items: ['Instagram Reel', 'Instagram Story', 'Instagram Post', 'YouTube Video', 'YouTube Short', 'TikTok Video', 'UGC Content', 'Other']
                          .map((type) => DropdownMenuItem(value: type, child: Text(type, style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _tempDelivType = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _tempDelivCountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Qty',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.textPrimary, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final count = int.tryParse(_tempDelivCountCtrl.text) ?? 1;
                      if (count > 0) {
                        setState(() {
                          _deliverables.add({'type': _tempDelivType, 'count': count});
                          _tempDelivCountCtrl.text = '1';
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.accentOnDark,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Icon(Icons.add, size: 16),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepPreview() {
    final deliverableStrings = _deliverables.map((d) => '${d['count']}x ${d['type']}').toList();
    
    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Preview Card', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('This is how your campaign card will look to creators.', style: AppTextStyles.captionSm.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 16),
        
        // Mock Card Preview
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Image
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: AppColors.surface2,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppImage(
                        url: _coverImageUrl,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.getCategoryColor(_category),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            _category.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            _campaignType,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titleCtrl.text.isNotEmpty ? _titleCtrl.text : 'Untitled Campaign',
                      style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _descCtrl.text.isNotEmpty ? _descCtrl.text : 'No description provided.',
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPreviewDetailItem(
                            Iconsax.wallet_3,
                            'Budget',
                            _budgetCtrl.text.isNotEmpty ? _budgetCtrl.text : 'Open / Unspecified',
                          ),
                        ),
                        Expanded(
                          child: _buildPreviewDetailItem(
                            Iconsax.clock,
                            'Timeline',
                            _timelineCtrl.text.isNotEmpty ? _timelineCtrl.text : 'Flexible',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPreviewDetailItem(
                            Iconsax.user_tick,
                            'Followers Target',
                            (() {
                              final Map<String, Object>? tier = _followerTiers.cast<Map<String, Object>?>().firstWhere(
                                (t) => t?['value'] == _minFollowers,
                                orElse: () => null,
                              );
                              if (tier != null) return tier['label'] as String;
                              return '${NumberFormat.compact().format(_minFollowers)}+ followers';
                            })(),
                          ),
                        ),
                        Expanded(
                          child: _buildPreviewDetailItem(
                            Iconsax.location,
                            'Preferred Location',
                            _preferredLocation,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPreviewDetailItem(
                            Iconsax.profile_2user,
                            'Number of Openings',
                            '${int.tryParse(_openingsCtrl.text) ?? 1} spots available',
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                    if (deliverableStrings.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('DELIVERABLES', style: AppTextStyles.overline),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: deliverableStrings.map((str) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(str, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                        )).toList(),
                      ),
                    ],
                    if (_applicationDeadline != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Iconsax.calendar_1, size: 14, color: AppColors.error),
                          const SizedBox(width: 6),
                          Text(
                            'Applications close: ${DateFormat('MMMM dd, yyyy').format(_applicationDeadline!)}',
                            style: AppTextStyles.captionSm.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewDetailItem(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.captionSm.copyWith(color: AppColors.textMuted, fontSize: 9)),
              Text(value, style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationRow() {
    final isLastStep = _currentStep == 3;
    final isFirstStep = _currentStep == 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Row(
        children: [
          if (!isFirstStep)
            Expanded(
              child: OutlinedButton(
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                child: Text('Back', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              ),
            ),
          if (!isFirstStep) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: isLastStep ? _save : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: isLastStep ? AppColors.accent : AppColors.accent,
                foregroundColor: AppColors.accentOnDark,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      isLastStep
                          ? (widget.card != null ? 'Save Changes' : 'Publish Campaign')
                          : 'Continue',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}