import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'providers/agent_provider.dart';
import 'providers/chat_provider.dart';
import 'repositories/agent_repository.dart';
import 'repositories/chat_repository.dart';
import 'routes/app_router.dart';

class AllyApp extends StatefulWidget {
  const AllyApp({
    super.key,
    required this.agentRepository,
    required this.chatRepository,
    this.config = const AppConfig(),
    this.initialLocation = '/splash',
    this.firstFrameReady,
  });
  final AgentRepository agentRepository;
  final ChatRepository chatRepository;
  final AppConfig config;
  final String initialLocation;

  /// The engine's first rasterized frame; injected by main for cold starts.
  final Future<void>? firstFrameReady;
  @override
  State<AllyApp> createState() => _AllyAppState();
}

class _AllyAppState extends State<AllyApp> with WidgetsBindingObserver {
  late final AgentProvider _agents = AgentProvider(
    widget.agentRepository,
    config: widget.config,
  );
  late final ChatProvider _chat = ChatProvider(widget.chatRepository, _agents);
  late final GoRouter _router = createAppRouter(
    _agents,
    initialLocation: widget.initialLocation,
    firstFrameReady: widget.firstFrameReady,
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _agents.checkExpiry();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    _chat.dispose();
    _agents.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: _agents),
      ChangeNotifierProvider.value(value: _chat),
    ],
    child: MaterialApp.router(
      title: 'ALLY',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: _router,
    ),
  );
}
