import 'dart:async';
import 'package:flutter/material.dart';
import '../../shared/widgets/app_snackbar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/services/chat_service.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/shared_widgets.dart';

class ImageViewerScreen extends ConsumerStatefulWidget {
  final List<String> urls;
  final int initialIndex;
  final String title;

  const ImageViewerScreen({
    super.key,
    required this.urls,
    required this.initialIndex,
    required this.title,
  });

  @override
  ConsumerState<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends ConsumerState<ImageViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  final _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails!.localPosition;
      _transformationController.value = Matrix4.identity()
        ..translate(-position.dx * 1.5, -position.dy * 1.5)
        ..scale(2.5);
    }
  }

  Future<void> _downloadImage(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      AppSnackbar.success(context, 'Image link copied to clipboard');
    }
  }

  Future<void> _shareImage(String url) async {
    try {
      await Share.shareUri(Uri.parse(url));
    } catch (e) {
      // Fallback if shareUri fails
      await Share.share(url);
    }
  }

  Future<void> _copyLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      AppSnackbar.success(context, 'Link copied to clipboard');
    }
  }

  Future<void> _forwardImage(String url) async {
    final chatService = ChatService();
    final user = ref.read(authProvider).user;
    final role = ref.read(authProvider).role;
    if (user == null || role == null) return;

    final rooms = await chatService.getRooms(user.id, role);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Iconsax.send_2, color: AppColors.accent, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Forward Photo',
                      style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                rooms.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('No chats to forward to.'),
                      )
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: rooms.length,
                          itemBuilder: (context, idx) {
                            final room = rooms[idx];
                            final isGroup = room['influencer_id'] == null;
                            final title = isGroup
                                ? (room['card']?['title'] ?? 'Group')
                                : ((role == 'brand' ? room['influencer'] : room['brand'])?['display_name'] as String?) ?? 'User';

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: isGroup
                                  ? Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: AppColors.accent.withValues(alpha: 0.1),
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
                                Navigator.pop(sheetCtx);
                                try {
                                  await chatService.forwardMessage(
                                    targetRoomId: room['id'] as String,
                                    senderId: user.id,
                                    content: 'Shared a photo',
                                    attachmentUrl: url,
                                    attachmentType: 'image',
                                    forwardedFrom: ref.read(authProvider).profile?['display_name'] ?? 'User',
                                  );
                                  if (mounted) {
                                    AppSnackbar.show(context, 'Photo forwarded to $title');
                                  }
                                } catch (e) {
                                  print('Error forwarding photo: $e');
                                }
                              },
                            );
                          },
                        ),
                      ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetCtx),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.urls.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(
          child: Text('No images to view', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final activeUrl = widget.urls[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.4),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              '${_currentIndex + 1} of ${widget.urls.length}',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Swipeable Image PageView
          GestureDetector(
            onDoubleTapDown: _handleDoubleTapDown,
            onDoubleTap: _handleDoubleTap,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.urls.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                  _transformationController.value = Matrix4.identity();
                });
              },
              itemBuilder: (context, index) {
                return Center(
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Image.network(
                      widget.urls[index],
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Text(
                            'Failed to load image',
                            style: TextStyle(color: Colors.white),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Action Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black.withOpacity(0.6),
              padding: EdgeInsets.only(
                top: 12,
                bottom: MediaQuery.of(context).padding.bottom + 12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: Icons.download_rounded,
                    label: 'Save',
                    onTap: () => _downloadImage(activeUrl),
                  ),
                  _buildActionButton(
                    icon: Icons.link_rounded,
                    label: 'Link',
                    onTap: () => _copyLink(activeUrl),
                  ),
                  _buildActionButton(
                    icon: Icons.share_rounded,
                    label: 'Share',
                    onTap: () => _shareImage(activeUrl),
                  ),
                  _buildActionButton(
                    icon: Icons.forward_rounded,
                    label: 'Forward',
                    onTap: () => _forwardImage(activeUrl),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
