import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/voice_state.dart';
import '../../providers/agent_provider.dart';
import '../../widgets/voice/voice_orb.dart';

class VoiceScreen extends StatelessWidget {
  const VoiceScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final agent = context.watch<AgentProvider>().session?.agent;
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        toolbarHeight: 80,
        leading: IconButton(
          tooltip: 'Back to assistants',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              agent?.name ?? 'ALLY Assistant',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Agent active · Voice not connected',
              style: TextStyle(color: AppColors.lightBlue, fontSize: 12),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Text(
                        'AI RECEPTIONIST',
                        style: TextStyle(
                          color: AppColors.lightBlue,
                          letterSpacing: 3,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: VoiceOrb(
                        state: VoiceState.idle,
                        size: math.min(260, (constraints.maxWidth - 48) / 1.25),
                      ),
                    ),
                    Column(
                      children: [
                        Icon(
                          Icons.mic_off_outlined,
                          color: AppColors.lightBlue,
                          size: 28,
                        ),
                        SizedBox(height: 18),
                        Text(
                          'Voice preview',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 340),
                          child: Text(
                            'Live voice is not connected yet. Your microphone is off. You can chat with your assistant in text mode.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.lightBlue,
                              height: 1.6,
                            ),
                          ),
                        ),
                        SizedBox(height: 28),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () => context.go('/chat'),
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: const Text('Open Chatbot'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.paleBlue,
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
