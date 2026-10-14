import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 48, this.onDark = false});
  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: onDark ? AppColors.violet.withValues(alpha: 0.18) : null,
        gradient: onDark ? null : AppGradients.brand,
        border: onDark
            ? Border.all(color: AppColors.violet.withValues(alpha: 0.55))
            : null,
        boxShadow: onDark
            ? [
                BoxShadow(
                  color: AppColors.violet.withValues(alpha: 0.12),
                  blurRadius: 28,
                ),
              ]
            : null,
      ),
      child: Icon(
        Icons.mic_rounded,
        color: AppColors.white,
        size: size * (onDark ? 0.42 : 0.52),
      ),
    ),
  );
}
