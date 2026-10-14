import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppGradients {
  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primary, AppColors.purple],
  );
  static const orb = RadialGradient(
    center: Alignment(-0.35, -0.45),
    radius: 1.1,
    colors: [
      AppColors.paleBlue,
      AppColors.lightBlue,
      AppColors.blue,
      AppColors.primary,
      AppColors.royal,
      AppColors.darkBlue,
    ],
    stops: [0, 0.22, 0.46, 0.66, 0.83, 1],
  );
  static const voice = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.midnight, AppColors.black],
    stops: [0, 0.5],
  );
}
