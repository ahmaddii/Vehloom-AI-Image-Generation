import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// WhatsApp-style emoji picker panel for the chat composer.
class ChatEmojiPicker extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onBackspace;
  final double height;

  const ChatEmojiPicker({
    super.key,
    required this.controller,
    required this.onBackspace,
    this.height = 280,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: height,
        child: EmojiPicker(
          onEmojiSelected: (category, emoji) {
            final text = controller.text;
            final selection = controller.selection;
            final start = selection.start >= 0 ? selection.start : text.length;
            final end = selection.end >= 0 ? selection.end : text.length;
            final newText = text.replaceRange(start, end, emoji.emoji);
            controller.value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(
                offset: start + emoji.emoji.length,
              ),
            );
          },
          onBackspacePressed: onBackspace,
          config: Config(
            height: height,
            checkPlatformCompatibility: true,
            emojiViewConfig: EmojiViewConfig(
              backgroundColor: AppColors.creamBg,
              columns: 7,
              emojiSizeMax: 32 * (defaultTargetPlatform == TargetPlatform.iOS ? 1.15 : 1.0),
              verticalSpacing: 2,
              horizontalSpacing: 2,
              gridPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              recentsLimit: 32,
              noRecents: Text(
                'No recent emojis',
                style: TextStyle(color: AppColors.lightGrey, fontSize: 14),
              ),
            ),
            categoryViewConfig: CategoryViewConfig(
              backgroundColor: AppColors.creamBg,
              indicatorColor: AppColors.coral,
              iconColor: AppColors.lightGrey,
              iconColorSelected: AppColors.coral,
              backspaceColor: AppColors.coral,
              recentTabBehavior: RecentTabBehavior.RECENT,
              tabIndicatorAnimDuration: kThemeAnimationDuration,
              initCategory: Category.SMILEYS,
            ),
            bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
            searchViewConfig: SearchViewConfig(
              backgroundColor: AppColors.creamBg,
              hintText: 'Search emoji',
              buttonIconColor: AppColors.coral,
            ),
            skinToneConfig: const SkinToneConfig(enabled: false),
          ),
        ),
      ),
    );
  }
}

/// Quick reaction bar shown on long-press (Messenger / WhatsApp style).
class ChatReactionBar extends StatelessWidget {
  final void Function(String emoji) onReactionSelected;
  final VoidCallback? onMoreReactions;

  static const defaultReactions = [
    '❤️',
    '😂',
    '😮',
    '😢',
    '🙏',
    '👍',
    '👎',
    '🔥',
  ];

  const ChatReactionBar({
    super.key,
    required this.onReactionSelected,
    this.onMoreReactions,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(28),
      color: AppColors.creamBg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...defaultReactions.map(
              (emoji) => _ReactionButton(
                emoji: emoji,
                onTap: () => onReactionSelected(emoji),
              ),
            ),
            if (onMoreReactions != null)
              IconButton(
                icon: Icon(Icons.add_reaction_outlined, color: AppColors.coral, size: 22),
                onPressed: onMoreReactions,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReactionButton extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;

  const _ReactionButton({required this.emoji, required this.onTap});

  @override
  State<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<_ReactionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1, end: 1.35).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(widget.emoji, style: const TextStyle(fontSize: 26)),
        ),
      ),
    );
  }
}
