import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../models/chat_message_model.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});
  final ChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    final user = message.role == MessageRole.user;
    final theme = Theme.of(context);
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.88,
        child: Align(
          alignment: user ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: user ? null : theme.colorScheme.surfaceContainerLow,
              gradient: user ? AppGradients.brand : null,
              border: user
                  ? null
                  : Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(user ? 20 : 4),
                bottomRight: Radius.circular(user ? 4 : 20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: user ? 'You' : 'Assistant',
                  child: SelectableText(
                    message.text,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: user
                          ? AppColors.white
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (message.delivery != MessageDelivery.sent) ...[
                  const SizedBox(height: 8),
                  Text(
                    message.delivery == MessageDelivery.failed
                        ? 'Delivery unconfirmed'
                        : 'Sending…',
                    style: const TextStyle(
                      color: AppColors.paleBlue,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
