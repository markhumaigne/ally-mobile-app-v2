import 'package:flutter/material.dart';

class FeedbackBanner extends StatelessWidget {
  const FeedbackBanner({
    super.key,
    required this.message,
    this.isError = false,
  });
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isError
              ? colors.errorContainer
              : colors.primaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.info_outline_rounded,
              size: 20,
              color: isError ? colors.onErrorContainer : colors.onSurface,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isError ? colors.onErrorContainer : colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
