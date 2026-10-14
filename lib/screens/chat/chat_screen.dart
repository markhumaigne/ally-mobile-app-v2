import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/agent_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/common/brand_mark.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final chat = context.read<ChatProvider>();
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
    if (_input.text.trim().isEmpty || _chat!.isSending) return;
    final text = _input.text;
    _input.clear();
    _chat!.send(text);
  }

  @override
  void dispose() {
    _chat?.removeListener(_onMessages);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agent = context.watch<AgentProvider>().session?.agent;
    final chat = context.watch<ChatProvider>();
    final theme = Theme.of(context);
    final messages = chat.messages;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
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
                Text(
                  'Agent active',
                  style: TextStyle(fontSize: 12, color: AppColors.paleBlue),
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
                              const SizedBox(height: 60),
                              const BrandMark(size: 72),
                              const SizedBox(height: 24),
                              Text(
                                'Start a conversation',
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'A question, an idea, a little help.\nYour assistant is one message away.',
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
                if (chat.error != null)
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: FeedbackBanner(
                        message:
                            '${chat.error!.message} '
                            'Delivery may be unconfirmed. Review the conversation before sending again.',
                        isError: true,
                      ),
                    ),
                  ),
                const Divider(height: 1),
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
                          decoration: const InputDecoration(
                            hintText: 'Message your assistant…',
                            labelText: 'Message',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _input,
                        builder: (context, value, _) => IconButton.filled(
                          key: const Key('send-button'),
                          tooltip: 'Send message',
                          onPressed: chat.isSending || value.text.trim().isEmpty
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
