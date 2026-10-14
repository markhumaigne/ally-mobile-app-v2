import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 48, this.onSplash = false});
  final double size;
  final bool onSplash;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: onSplash ? AppColors.white.withValues(alpha: 0.12) : null,
        gradient: onSplash ? null : AppGradients.brand,
        border: onSplash
            ? Border.all(
                color: AppColors.white.withValues(alpha: 0.4),
                width: 1.5,
              )
            : null,
      ),
      child: Icon(
        Icons.mic_rounded,
        color: AppColors.white,
        size: size * (onSplash ? 0.42 : 0.52),
      ),
    ),
  );
}
