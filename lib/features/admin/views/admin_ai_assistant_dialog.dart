import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/ai_assistant_provider.dart';

class AdminAiAssistantDialog extends ConsumerStatefulWidget {
  const AdminAiAssistantDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const AdminAiAssistantDialog(),
    );
  }

  @override
  ConsumerState<AdminAiAssistantDialog> createState() => _AdminAiAssistantDialogState();
}

class _AdminAiAssistantDialogState extends ConsumerState<AdminAiAssistantDialog> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<String> _quickSuggestions = [
    '📊 فرۆش و قازانجی ئەمڕۆ چەندە؟',
    '📈 قازانجی ئەم مانگە چەندە؟',
    '💳 کێ زۆرترین قەرزی لەسەرە؟',
    '📦 کام کاڵایە لە کۆگا کەمبووەتەوە؟',
    '👥 ئاماری فرۆشی مەندوبەکان بۆم دەربێنە',
  ];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend([String? presetText]) {
    final text = presetText ?? _textController.text;
    if (text.trim().isEmpty) return;

    ref.read(aiAssistantProvider.notifier).sendMessage(text);
    _textController.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final aiState = ref.watch(aiAssistantProvider);
    final screenSize = MediaQuery.of(context).size;

    final dialogWidth = screenSize.width > 700 ? 640.0 : screenSize.width * 0.94;
    final dialogHeight = screenSize.height > 800 ? 700.0 : screenSize.height * 0.88;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            _buildHeader(context, isDark),

            const Divider(height: 1, thickness: 1),

            // Chat Messages List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                itemCount: aiState.messages.length + (aiState.isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == aiState.messages.length && aiState.isLoading) {
                    return _buildLoadingBubble(isDark);
                  }
                  final msg = aiState.messages[index];
                  return _buildMessageBubble(msg, isDark);
                },
              ),
            ),

            // Quick Suggestions Chips (only if not loading)
            if (!aiState.isLoading)
              _buildSuggestionsBar(isDark),

            const Divider(height: 1, thickness: 1),

            // Input Bar
            _buildInputBar(isDark, aiState.isLoading),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceContainerDark
            : AppColors.primaryLight.withValues(alpha: 0.4),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.primaryDark : AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Symbols.auto_awesome,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'یاریدەدەری زیرەکی GARDI (Gemini)',
                  style: AppTextStyles.h3.copyWith(
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'شیکاری دارایی، فرۆشتن، کۆگا و قەرزەکان',
                  style: AppTextStyles.caption.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'دەستپێکردنەوەی گفتوگۆ',
            icon: Icon(
              Symbols.refresh,
              size: 20,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
            onPressed: () {
              ref.read(aiAssistantProvider.notifier).clearConversation();
            },
          ),
          IconButton(
            tooltip: 'داخستن',
            icon: Icon(
              Symbols.close,
              size: 20,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AiChatMessage msg, bool isDark) {
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              margin: const EdgeInsets.only(top: 4, left: 8),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: msg.isError
                    ? AppColors.danger.withValues(alpha: 0.15)
                    : (isDark ? AppColors.surfaceContainerHighestDark : AppColors.primaryLight),
                shape: BoxShape.circle,
              ),
              child: Icon(
                msg.isError ? Symbols.error : Symbols.smart_toy,
                size: 16,
                color: msg.isError
                    ? AppColors.danger
                    : (isDark ? AppColors.primaryDark : AppColors.primary),
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? (isDark ? AppColors.primaryDark : AppColors.primary)
                    : (isDark
                        ? AppColors.surfaceContainerDark
                        : (msg.isError ? const Color(0xFFFDE8E8) : const Color(0xFFF3F6FB))),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.lg),
                  topRight: const Radius.circular(AppRadius.lg),
                  bottomLeft: Radius.circular(isUser ? AppRadius.lg : AppRadius.xs),
                  bottomRight: Radius.circular(isUser ? AppRadius.xs : AppRadius.lg),
                ),
                border: Border.all(
                  color: isUser
                      ? Colors.transparent
                      : (isDark ? AppColors.borderDark : AppColors.borderLight),
                  width: 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    msg.content,
                    style: AppTextStyles.body.copyWith(
                      color: isUser
                          ? Colors.white
                          : (isDark
                              ? AppColors.textPrimaryDark
                              : (msg.isError ? AppColors.danger : AppColors.textPrimaryLight)),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(msg.timestamp),
                        style: AppTextStyles.caption.copyWith(
                          color: isUser
                              ? Colors.white.withValues(alpha: 0.7)
                              : (isDark
                                  ? AppColors.textDisabledDark
                                  : AppColors.textDisabledLight),
                          fontSize: 10,
                        ),
                      ),
                      if (!isUser && msg.source != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          msg.source == 'gemini' ? '• Gemini 3.8' : '• لۆکاڵی',
                          style: AppTextStyles.caption.copyWith(
                            color: isDark ? AppColors.infoDark : AppColors.info,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            Container(
              margin: const EdgeInsets.only(top: 4, right: 8),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.primaryContainerDark : AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Symbols.person,
                size: 16,
                color: isDark ? AppColors.primaryDark : AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingBubble(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4, left: 8),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceContainerHighestDark : AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Symbols.auto_awesome,
              size: 16,
              color: isDark ? AppColors.primaryDark : AppColors.primary,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceContainerDark : const Color(0xFFF3F6FB),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? AppColors.primaryDark : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'خەریکی شیکاری داتاکانی ERP و ژمێریارییە...',
                  style: AppTextStyles.caption.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsBar(bool isDark) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _quickSuggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final suggestion = _quickSuggestions[index];
          return ActionChip(
            label: Text(
              suggestion,
              style: AppTextStyles.caption.copyWith(
                color: isDark ? AppColors.textPrimaryDark : AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: isDark
                ? AppColors.surfaceContainerHighestDark
                : AppColors.primaryLight.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.full),
              side: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.primaryLight,
                width: 0.6,
              ),
            ),
            onPressed: () => _handleSend(suggestion),
          );
        },
      ),
    );
  }

  Widget _buildInputBar(bool isDark, bool isLoading) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 8),
      color: isDark ? AppColors.surfaceContainerDark : Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              enabled: !isLoading,
              textDirection: TextDirection.rtl,
              style: AppTextStyles.body.copyWith(
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
              decoration: InputDecoration(
                hintText: 'پرسیارێک لەسەر فرۆش، قازانج یان کۆگا بنووسە...',
                hintStyle: AppTextStyles.body.copyWith(
                  color: isDark ? AppColors.textDisabledDark : AppColors.textDisabledLight,
                  fontSize: 13,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.primaryDark : AppColors.primary,
                    width: 1.4,
                  ),
                ),
                filled: true,
                fillColor: isDark
                    ? AppColors.surfaceDark
                    : AppColors.surfaceContainerLight.withValues(alpha: 0.5),
              ),
              onSubmitted: (_) => _handleSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            icon: const Icon(Symbols.send, size: 18),
            style: IconButton.styleFrom(
              backgroundColor: isDark ? AppColors.primaryDark : AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(12),
            ),
            onPressed: isLoading ? null : () => _handleSend(),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
