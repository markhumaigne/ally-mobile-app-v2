import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppGradients {
  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primary, AppColors.teal],
  );
  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.navy, AppColors.darkNavy, Color(0xFF07555C)],
  );
  static const orb = RadialGradient(
    center: Alignment(-0.35, -0.45),
    radius: 1.1,
    colors: [
      Color(0xFF318D94),
      Color(0xFF106477),
      Color(0xFF0E425E),
      AppColors.navy,
      Color(0xFF071F35),
      AppColors.midnight,
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
