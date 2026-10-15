import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/agent_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/voice_provider.dart';
import '../../models/chat_message_model.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/common/feedback_banner.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  ChatProvider? _chat;
  VoiceProvider? _voice;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final chat = context.read<ChatProvider>();
    _voice = context.read<VoiceProvider>();
    if (_chat != chat) {
      _chat?.removeListener(_onMessages);
      _chat = chat;
      chat.addListener(_onMessages);
    }
  }

  void _onMessages() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  void _send() {
    if (_input.text.trim().isEmpty ||
        _chat!.isSending ||
        !_voice!.canSendText) {
      return;
    }
    final text = _input.text;
    _input.clear();
    if (_voice!.connected) {
      _voice!.sendText(text);
    } else {
      _chat!.send(text);
    }
  }

  @override
  void dispose() {
    // Schedule after this frame: route teardown must not notify widgets while
    // their element tree is being unmounted. Resources stop immediately next turn.
    final voice = _voice;
    Future.microtask(() => voice?.stop());
    _chat?.removeListener(_onMessages);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agent = context.watch<AgentProvider>().session?.agent;
    final chat = context.watch<ChatProvider>();
    final voice = context.watch<VoiceProvider>();
    final theme = Theme.of(context);
    final messages = chat.messages;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        leading: IconButton(
          tooltip: 'Back to assistants',
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              agent?.name ?? 'ALLY Assistant',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Row(
              children: [
                Icon(Icons.circle, color: AppColors.green, size: 7),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Powered by HumAIn',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: AppColors.paleBlue),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                Expanded(
                  child: messages.isEmpty
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              const SizedBox(height: 48),
                              Text(
                                'Welcome',
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Press the voice button to hear your assistant’s introduction, or type a message below.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          reverse: true,
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                          itemCount: messages.length,
                          itemBuilder: (context, index) => MessageBubble(
                            message: messages[messages.length - 1 - index],
                          ),
                        ),
                ),
                if (chat.isSending)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 4, 24, 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Expanded(child: Text('Waiting for your assistant…')),
                      ],
                    ),
                  ),
                if (chat.error != null || voice.error != null)
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FeedbackBanner(
                            message: (chat.error ?? voice.error)!.message,
                            isError: true,
                          ),
                          if (chat.error != null &&
                              messages.any(
                                (m) => m.delivery == MessageDelivery.failed,
                              ))
                            TextButton(
                              key: const Key('edit-failed-message'),
                              onPressed: () {
                                _input.text = messages
                                    .lastWhere(
                                      (m) =>
                                          m.delivery == MessageDelivery.failed,
                                    )
                                    .text;
                                _input.selection = TextSelection.collapsed(
                                  offset: _input.text.length,
                                );
                              },
                              child: const Text('Edit last message'),
                            ),
                        ],
                      ),
                    ),
                  ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: voice.connected
                              ? AppColors.green
                              : AppColors.chatMuted,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            chat.isSending
                                ? 'Waiting for a reply…'
                                : voice.statusLabel,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('chat-input'),
                          controller: _input,
                          minLines: 1,
                          maxLines: 5,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: 'Ask anything',
                            fillColor: AppColors.chatComposer,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(32),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _input,
                        builder: (context, value, _) =>
                            value.text.trim().isEmpty
                            ? IconButton.filled(
                                key: const Key('voice-button'),
                                tooltip: voice.connected || voice.busy
                                    ? 'Stop voice'
                                    : 'Start voice',
                                onPressed: chat.isSending
                                    ? null
                                    : () {
                                        FocusScope.of(context).unfocus();
                                        if (voice.connected || voice.busy) {
                                          voice.stop();
                                        } else {
                                          voice.start();
                                        }
                                      },
                                icon: Icon(
                                  voice.connected || voice.busy
                                      ? Icons.stop_rounded
                                      : Icons.graphic_eq_rounded,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: voice.connected
                                      ? AppColors.red
                                      : AppColors.white,
                                  foregroundColor: voice.connected
                                      ? AppColors.white
                                      : AppColors.chatHeader,
                                  minimumSize: const Size(52, 52),
                                ),
                              )
                            : IconButton.filled(
                                key: const Key('send-button'),
                                tooltip: 'Send message',
                                onPressed: chat.isSending || !voice.canSendText
                                    ? null
                                    : _send,
                                icon: const Icon(Icons.arrow_upward_rounded),
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(52, 52),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                if (voice.connected || voice.busy)
                  TextButton.icon(
                    onPressed: voice.stop,
                    icon: const Icon(Icons.mic_off_rounded, size: 18),
                    label: const Text('Stop voice · Keep chatting'),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Powered by ALLY · HumAIn PH',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
