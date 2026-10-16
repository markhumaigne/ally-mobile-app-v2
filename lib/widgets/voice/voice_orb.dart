import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../models/voice_state.dart';
import '../common/brand_mark.dart';

/// Presentation only. The screen supplies live state from VoiceProvider.
class VoiceOrb extends StatefulWidget {
  const VoiceOrb({super.key, required this.state, this.size = 260});
  final VoiceState state;
  final double size;
  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(vsync: this);

  void _syncAnimation() {
    final duration = switch (widget.state) {
      VoiceState.thinking => const Duration(milliseconds: 3200),
      VoiceState.connecting => const Duration(milliseconds: 4200),
      VoiceState.speaking => const Duration(milliseconds: 1800),
      VoiceState.listening => const Duration(milliseconds: 3000),
      _ => const Duration(milliseconds: 5600),
    };
    final changedSpeed = _animation.duration != duration;
    _animation.duration = duration;
    final stopped =
        MediaQuery.disableAnimationsOf(context) ||
        widget.state == VoiceState.disconnected ||
        widget.state == VoiceState.error;
    if (stopped) {
      _animation.stop();
      _animation.value = 0;
    } else if (!_animation.isAnimating || changedSpeed) {
      _animation.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(VoiceOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Voice orb: ${widget.state.label}',
    image: true,
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          final energetic =
              widget.state == VoiceState.speaking ||
              widget.state == VoiceState.listening;
          final flowing =
              widget.state == VoiceState.thinking ||
              widget.state == VoiceState.connecting;
          final phase = _animation.value * math.pi * 2;
          // Closed sine/cosine cycles keep the light and pulse seamless.
          final pulse = (1 - math.cos(phase)) / 2;
          final gradient = flowing
              ? RadialGradient(
                  center: Alignment(
                    -0.35 + math.sin(phase) * 0.3,
                    -0.45 + pulse * 0.45,
                  ),
                  radius: 1.1 + pulse * 0.08,
                  colors: AppGradients.orb.colors,
                  stops: AppGradients.orb.stops,
                )
              : AppGradients.orb;
          final glow = widget.state == VoiceState.error
              ? AppColors.red
              : AppColors.cyan;
          return SizedBox(
            width: widget.size * 1.25,
            height: widget.size * 1.25,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (flowing)
                  for (var ring = 0; ring < 2; ring++) _haloRing(phase, ring),
                Center(
                  child: Transform.scale(
                    scale:
                        1 +
                        pulse *
                            (energetic
                                ? 0.06
                                : flowing
                                ? 0.035
                                : 0.018),
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: gradient,
                        border: Border.all(
                          color: AppColors.cyan.withValues(alpha: 0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: glow.withValues(alpha: 0.16 + pulse * 0.09),
                            blurRadius: 58,
                            spreadRadius: 14 + pulse * 10,
                          ),
                          BoxShadow(
                            color: glow.withValues(alpha: 0.28),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: widget.state == VoiceState.error
                          ? const Icon(
                              Icons.error_outline_rounded,
                              size: 48,
                              color: AppColors.white,
                            )
                          : Center(child: BrandMark(size: widget.size * 0.6)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );

  Widget _haloRing(double phase, int index) {
    final wave = (1 - math.cos(phase + index * math.pi)) / 2;
    return IgnorePointer(
      child: Container(
        width: widget.size * (1.06 + wave * 0.12),
        height: widget.size * (1.06 + wave * 0.12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.mint.withValues(alpha: 0.2 * (1 - wave)),
            width: 1.2,
          ),
        ),
      ),
    );
  }
}
