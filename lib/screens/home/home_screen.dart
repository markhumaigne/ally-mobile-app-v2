import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/validation/uuid_validator.dart';
import '../../providers/agent_provider.dart';
import '../../providers/voice_provider.dart';
import '../../widgets/agent/assistant_card.dart';
import '../../widgets/common/brand_mark.dart';
import '../../widgets/common/brand_hero.dart';
import '../../widgets/common/feedback_banner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _form = GlobalKey<FormState>();
  final _agentId = TextEditingController();
  final _userId = TextEditingController();
  final _scrollController = ScrollController();
  bool _exiting = false;

  @override
  void dispose() {
    _agentId.dispose();
    _userId.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _activate() {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    context.read<AgentProvider>().activate(
      _agentId.text,
      userReference: _userId.text,
    );
  }

  void _backToAgentForm() {
    FocusScope.of(context).unfocus();
    context.read<AgentProvider>().reset();
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  Future<void> _exitApp() async {
    if (_exiting) return;
    setState(() => _exiting = true);
    FocusScope.of(context).unfocus();
    try {
      await context.read<VoiceProvider>().stop();
      if (!mounted) return;
      await SystemNavigator.pop();
    } finally {
      if (mounted) setState(() => _exiting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final agent = context.watch<AgentProvider>();
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: dark
                                    ? const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      )
                                    : EdgeInsets.zero,
                                decoration: BoxDecoration(
                                  color: dark ? AppColors.background : null,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const BrandBanner(width: 150),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'YOUR EVERYDAY\nAI COMPANION',
                                  textAlign: TextAlign.end,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    letterSpacing: 1,
                                    fontSize: 9,
                                    height: 1.7,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          if (agent.hasSession)
                            ..._selection(context, agent)
                          else
                            ..._activation(context, agent),
                          const SizedBox(height: 28),
                          const Divider(),
                          const SizedBox(height: 16),
                          Text(
                            'A little intelligence. A lot of possibility.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Created by HumAIn PH',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              key: Key(
                                agent.hasSession
                                    ? 'back-to-agent-form-button'
                                    : 'exit-app-button',
                              ),
                              onPressed: agent.hasSession
                                  ? _backToAgentForm
                                  : (_exiting ? null : _exitApp),
                              icon: Icon(
                                agent.hasSession
                                    ? Icons.arrow_back_rounded
                                    : Icons.exit_to_app_rounded,
                              ),
                              label: Text(agent.hasSession ? 'Back' : 'Exit'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                foregroundColor:
                                    theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _activation(BuildContext context, AgentProvider agent) {
    final theme = Theme.of(context);
    return [
      const BrandHero(
        eyebrow: 'YOUR AI, ONE TAP AWAY',
        title: 'Launch Your\nAI Agent',
        description:
            'A conversation away from what’s next. Connect with your assistant through text or voice.',
      ),
      const SizedBox(height: 20),
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Connect your agent', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Enter your Agent UUID to get started.',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  key: const Key('agent-id'),
                  controller: _agentId,
                  enabled: !agent.isLoading,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Agent UUID',
                    hintText: 'Enter your Agent UUID',
                    prefixIcon: Icon(Icons.fingerprint_rounded),
                  ),
                  validator: UuidValidator.validate,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const Key('user-id'),
                  controller: _userId,
                  enabled: !agent.isLoading,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'User ID (optional)',
                    hintText: 'Optional session reference',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  onFieldSubmitted: (_) => _activate(),
                ),
                const SizedBox(height: 8),
                Text(
                  'Optional. Used only for this conversation.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('activate-button'),
                  onPressed: agent.isLoading ? null : _activate,
                  icon: agent.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    agent.isLoading ? 'Validating agent…' : 'Launch assistant',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      if (agent.error != null) ...[
        const SizedBox(height: 16),
        FeedbackBanner(message: agent.error!.message, isError: true),
      ] else if (agent.config.configurationError != null) ...[
        const SizedBox(height: 16),
        FeedbackBanner(message: agent.config.configurationError!.message),
      ],
      const SizedBox(height: 20),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Your agent’s active status is checked before you begin.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _selection(BuildContext context, AgentProvider provider) {
    final theme = Theme.of(context);
    final agent = provider.session!.agent;
    return [
      const BrandHero(
        eyebrow: 'MADE FOR YOUR EVERYDAY',
        title: 'Choose Your\nAI Assistant',
        description: 'One assistant. Two ways to connect.',
      ),
      const SizedBox(height: 24),
      Semantics(
        liveRegion: true,
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.teal,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Agent active', style: theme.textTheme.labelLarge),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Text(agent.name, style: theme.textTheme.titleLarge),
      const SizedBox(height: 20),
      Builder(
        builder: (context) {
          final cards = [
            AssistantCard(
              key: const Key('chat-card'),
              title: 'Chatbot',
              description: 'Talk or type with your AI agent.',
              icon: Icons.chat_bubble_outline_rounded,
              color: theme.colorScheme.primary,
              badge: 'TEXT + VOICE',
              onTap: () => context.go('/chat'),
            ),
            AssistantCard(
              key: const Key('voice-card'),
              title: 'Voice Orb',
              description: 'Talk naturally with your AI assistant.',
              icon: Icons.mic_none_rounded,
              color: theme.colorScheme.secondary,
              badge: 'HANDS-FREE',
              onTap: () => context.go('/voice'),
            ),
          ];
          return MediaQuery.sizeOf(context).width >= 648
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 16),
                    Expanded(child: cards[1]),
                  ],
                )
              : Column(
                  children: [cards[0], const SizedBox(height: 16), cards[1]],
                );
        },
      ),
    ];
  }
}
