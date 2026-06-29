import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final Future<void> Function() onSend;
  final VoidCallback onAttach;

  final bool isBlocked;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onAttach,
    this.isBlocked = false,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  bool _isSending = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  Future<void> _handleSend() async {
    if (widget.controller.text.trim().isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _hasError = false;
    });

    try {
      await widget.onSend();
      setState(() {
        _hasError = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isBlocked) {
      return Container(
        color: AppColors.surface,
        width: double.infinity,
        alignment: Alignment.center,
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).padding.bottom + 16,
        ),
        child: Text(
          'This conversation is disabled.',
          style: AppTextStyles.body.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasText = widget.controller.text.trim().isNotEmpty;

    final Color sendButtonColor = _hasError
        ? AppColors.error
        : (hasText
            ? AppColors.accent
            : (isDark ? const Color(0xFF2A2A2E) : const Color(0xFFE5E7EB)));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Error banner
        if (_hasError)
          Container(
            color: AppColors.error.withValues(alpha: 0.1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            width: double.infinity,
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Failed to send message.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.error),
                  ),
                ),
                GestureDetector(
                  onTap: _handleSend,
                  child: Text(
                    'Tap to retry',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // Input bar
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0xFF1F1F23) : const Color(0xFFF0F0F0),
                width: 0.5,
              ),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            8,
            8,
            8,
            MediaQuery.of(context).viewInsets.bottom > 0
                ? 8
                : MediaQuery.of(context).padding.bottom + 8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Plus / Attach button
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(bottom: 2),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Iconsax.add,
                    color: isDark ? AppColors.textSecondary : const Color(0xFF6E6E73),
                    size: 24,
                  ),
                  onPressed: widget.onAttach,
                  tooltip: 'Attach',
                ),
              ),
              const SizedBox(width: 4),

              // Text field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8E8ED),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: widget.controller,
                    style: AppTextStyles.body.copyWith(fontSize: 14),
                    keyboardType: TextInputType.multiline,
                    maxLines: 6,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Send button
              GestureDetector(
                onTap: (hasText && !_isSending) ? _handleSend : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    color: sendButtonColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _hasError ? Icons.close : Iconsax.send_1,
                            color: Colors.white,
                            size: 18,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
