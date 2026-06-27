import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/design_tokens.dart';

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

class _ChatInputBarState extends State<ChatInputBar> with SingleTickerProviderStateMixin {
  bool _isSending = false;
  bool _hasError = false;
  bool _showEmoji = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showEmoji) {
        setState(() {
          _showEmoji = false;
        });
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // Force rebuild to update the send button state and animation
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

  void _toggleEmojiPicker() {
    if (_showEmoji) {
      _focusNode.requestFocus();
      setState(() {
        _showEmoji = false;
      });
    } else {
      _focusNode.unfocus();
      // Wait for keyboard to start hiding before showing emoji picker
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            _showEmoji = true;
          });
        }
      });
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
          DesignTokens.space12,
          DesignTokens.space16,
          DesignTokens.space12,
          MediaQuery.of(context).padding.bottom + DesignTokens.space16,
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
    
    // Animation color tween for send button: grey (empty) to purple (has text)
    final Color sendButtonColor = _hasError
        ? AppColors.error
        : (hasText ? AppColors.purple : (isDark ? const Color(0xFF555555) : const Color(0xFFD1D1D6)));

    return WillPopScope(
      onWillPop: () async {
        if (_showEmoji) {
          setState(() {
            _showEmoji = false;
          });
          return false;
        }
        return true;
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_hasError)
            Container(
              color: AppColors.error.withOpacity(0.1),
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
          Container(
            color: AppColors.surface,
            padding: EdgeInsets.fromLTRB(
              DesignTokens.space12,
              DesignTokens.space8,
              DesignTokens.space12,
              MediaQuery.of(context).viewInsets.bottom > 0
                  ? DesignTokens.space8
                  : MediaQuery.of(context).padding.bottom + DesignTokens.space8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attach button
                IconButton(
                  icon: Icon(
                    Iconsax.add,
                    color: isDark ? AppColors.textSecondary : const Color(0xFF6E6E73),
                    size: DesignTokens.iconMD,
                  ),
                  onPressed: widget.onAttach,
                  tooltip: 'Attach photos or files',
                ),
                
                // Emoji button
                IconButton(
                  icon: Icon(
                    _showEmoji ? Icons.keyboard : Icons.sentiment_satisfied_alt_outlined,
                    color: isDark ? AppColors.textSecondary : const Color(0xFF6E6E73),
                    size: DesignTokens.iconMD,
                  ),
                  onPressed: _toggleEmojiPicker,
                  tooltip: 'Emoji picker',
                ),
                
                // Input text field
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(DesignTokens.radius2XL),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      style: AppTextStyles.body,
                      keyboardType: TextInputType.multiline,
                      maxLines: 6,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Message',
                        hintStyle: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
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
                
                // Send button with animated color transition
                GestureDetector(
                  onTap: (hasText && !_isSending) ? _handleSend : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
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
          
          // Emoji Picker Panel
          if (_showEmoji)
            SizedBox(
              height: 260,
              child: EmojiPicker(
                textEditingController: widget.controller,
                config: Config(
                  height: 256,
                  emojiViewConfig: EmojiViewConfig(
                    columns: 7,
                    emojiSizeMax: 28,
                    backgroundColor: AppColors.surface,
                    gridPadding: EdgeInsets.zero,
                    recentsLimit: 28,
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    backgroundColor: AppColors.surface,
                    indicatorColor: AppColors.purple,
                    iconColor: AppColors.textSecondary,
                    iconColorSelected: AppColors.purple,
                    backspaceColor: AppColors.purple,
                  ),
                  bottomActionBarConfig: BottomActionBarConfig(
                    backgroundColor: AppColors.surface,
                    buttonColor: AppColors.surface,
                    buttonIconColor: AppColors.purple,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
