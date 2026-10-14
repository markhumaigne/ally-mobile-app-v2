import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../models/voice_state.dart';

/// Presentation only. A future audio transport supplies the real state.
class VoiceOrb extends StatefulWidget {
  const VoiceOrb({super.key, required this.state, this.size = 260});
  final VoiceState state;
  final double size;
  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );

  void _syncAnimation() {
    final stopped =
        MediaQuery.disableAnimationsOf(context) ||
        widget.state == VoiceState.disconnected ||
        widget.state == VoiceState.error;
    if (stopped) {
      _animation.stop();
      _animation.value = 0;
    } else if (!_animation.isAnimating) {
      _animation.repeat(reverse: true);
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
    child: AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final energetic =
            widget.state == VoiceState.speaking ||
            widget.state == VoiceState.listening;
        final pulse = math.sin(_animation.value * math.pi);
        final glow = widget.state == VoiceState.error
            ? AppColors.red
            : AppColors.blue;
        return SizedBox(
          width: widget.size * 1.25,
          height: widget.size * 1.25,
          child: Center(
            child: Transform.scale(
              scale: 1 + pulse * (energetic ? 0.06 : 0.018),
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppGradients.orb,
                  border: Border.all(
                    color: AppColors.lightBlue.withValues(alpha: 0.5),
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
                child:
                    widget.state == VoiceState.connecting ||
                        widget.state == VoiceState.thinking
                    ? const Center(
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        ),
                      )
                    : widget.state == VoiceState.error
                    ? const Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: AppColors.white,
                      )
                    : null,
              ),
            ),
          ),
        );
      },
    ),
  );
}
