import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/agent_provider.dart';
import '../../widgets/common/brand_mark.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.firstFrameReady});
  final Future<void>? firstFrameReady;
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    // Leave the fully visible branding on screen long enough to read it.
    // This is an intro, not a simulated backend request.
    duration: const Duration(seconds: 2),
    // Reduced motion keeps the content still, with the same time to read it.
    animationBehavior: AnimationBehavior.preserve,
  )..addStatusListener(_onEntranceStatus);
  late final Animation<double> _scale = _entrance.drive(
    Tween<double>(begin: 0.98, end: 1).chain(
      CurveTween(curve: const Interval(0, 0.15, curve: Curves.easeOutCubic)),
    ),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // A build callback can run before Android has displayed Flutter at all.
      // Don't spend the introduction's display time starting the engine.
      await widget.firstFrameReady;
      if (mounted) _entrance.forward();
    });
  }

  void _onEntranceStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      context.read<AgentProvider>().initialize();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppColors.loadingBackground,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.loadingBackground,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.loadingBackground,
        body: SafeArea(
          child: Align(
            alignment: const Alignment(0, -0.06),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ScaleTransition(
                scale: reduceMotion
                    ? const AlwaysStoppedAnimation(1.0)
                    : _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BrandMark(size: 80, onSplash: true),
                    const SizedBox(height: 24),
                    const Text(
                      'ALLY',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Created by HumAIn PH',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        value: reduceMotion ? 0.75 : null,
                        strokeWidth: 2.5,
                        strokeCap: StrokeCap.round,
                        color: AppColors.white.withValues(alpha: 0.7),
                        semanticsLabel: 'Starting ALLY',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
