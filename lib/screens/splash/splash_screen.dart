import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/agent_provider.dart';
import '../../widgets/common/brand_mark.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AgentProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) =>
      const AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.royal,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BrandMark(size: 104, onBlue: true),
                    SizedBox(height: 28),
                    Text(
                      'ALLY',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 56,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Created by HumAIn PH',
                      style: TextStyle(color: AppColors.paleBlue, fontSize: 16),
                    ),
                    SizedBox(height: 48),
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                        semanticsLabel: 'Initializing ALLY',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
