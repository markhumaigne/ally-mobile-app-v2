import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 48, this.onBlue = false});
  final double size;
  final bool onBlue;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: onBlue ? AppColors.white.withValues(alpha: 0.16) : null,
        gradient: onBlue ? null : AppGradients.brand,
        border: onBlue
            ? Border.all(color: AppColors.white.withValues(alpha: 0.3))
            : null,
      ),
      child: Icon(Icons.mic_rounded, color: AppColors.white, size: size * 0.52),
    ),
  );
}
