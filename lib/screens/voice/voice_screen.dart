import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/voice_state.dart';
import '../../providers/agent_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/voice_provider.dart';
import '../../widgets/common/feedback_banner.dart';
import '../../widgets/voice/voice_orb.dart';

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});
  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  VoiceProvider? _voice;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _voice = context.read<VoiceProvider>();
  }

  void _toggleVoice() {
    final voice = _voice!;
    if (voice.busy || voice.connected) {
      voice.stop();
    } else {
      voice.start();
    }
  }

  void _openChat() {
    // Begin releasing audio immediately; navigation need not wait for socket
    // cleanup. VoiceProvider waits for cleanup before another session starts.
    _voice!.stop();
    context.go('/chat');
  }

  @override
  void dispose() {
    // Route teardown must not notify widgets while they are unmounting.
    final voice = _voice;
    Future.microtask(() => voice?.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agent = context.watch<AgentProvider>().session?.agent;
    final voice = context.watch<VoiceProvider>();
    final waitingForChat = context.select<ChatProvider, bool>(
      (chat) => chat.isSending,
    );
    final active = voice.busy || voice.connected;
    final canToggle = active || !waitingForChat;
    final statusLabel = switch (voice.state) {
      VoiceState.idle || VoiceState.disconnected => 'Ready to start',
      VoiceState.error => 'Voice unavailable',
      _ => voice.statusLabel,
    };
    final actionLabel = voice.busy
        ? 'Cancel'
        : voice.connected
        ? 'Stop voice'
        : voice.error != null
        ? 'Tap to retry'
        : 'Tap to start';
    final hint = switch (voice.state) {
      VoiceState.connecting => 'Connecting to your assistant…',
      VoiceState.listening => 'You can speak now.',
      VoiceState.thinking => 'Your assistant will speak shortly.',
      VoiceState.speaking => 'Your assistant is speaking. Please wait.',
      _ => 'Your assistant will introduce itself, then listen.',
    };
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
            Text(
              voice.connected
                  ? 'Agent active · Voice connected'
                  : voice.busy
                  ? 'Agent active · Connecting'
                  : 'Agent active · Voice not connected',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.lightBlue, fontSize: 12),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
                minWidth: constraints.maxWidth,
              ),
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
                      child: Semantics(
                        button: true,
                        enabled: canToggle,
                        label: active ? 'Stop voice' : 'Start voice',
                        onTap: canToggle ? _toggleVoice : null,
                        child: ExcludeSemantics(
                          child: GestureDetector(
                            key: const Key('orb-voice-button'),
                            onTap: canToggle ? _toggleVoice : null,
                            child: VoiceOrb(
                              state: voice.state,
                              size: math.min(
                                260,
                                (constraints.maxWidth - 48) / 1.25,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            waitingForChat && !active
                                ? 'Waiting for your last message…'
                                : statusLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 340),
                          child: voice.error != null
                              ? FeedbackBanner(
                                  message: voice.error!.message,
                                  isError: true,
                                )
                              : Text(
                                  hint,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.lightBlue,
                                    height: 1.6,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          key: const Key('orb-session-button'),
                          onPressed: canToggle ? _toggleVoice : null,
                          icon: Icon(
                            active ? Icons.stop_rounded : Icons.mic_rounded,
                          ),
                          label: Text(actionLabel),
                          style: FilledButton.styleFrom(
                            backgroundColor: active
                                ? AppColors.red
                                : AppColors.primary,
                            foregroundColor: AppColors.white,
                            minimumSize: const Size(180, 56),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: _openChat,
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
