import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/agent_provider.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/voice/voice_screen.dart';

GoRouter createAppRouter(
  AgentProvider agents, {
  String initialLocation = '/splash',
  Future<void>? firstFrameReady,
}) => GoRouter(
  initialLocation: initialLocation,
  refreshListenable: agents,
  redirect: (context, state) {
    final path = state.uri.path;
    if (!agents.initialized) return path == '/splash' ? null : '/splash';
    if (path == '/splash') return '/';
    if ((path == '/chat' || path == '/voice') && !agents.hasSession) return '/';
    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      builder: (_, _) => SplashScreen(firstFrameReady: firstFrameReady),
    ),
    GoRoute(
      path: '/',
      builder: (_, _) => const HomeScreen(),
      routes: [
        GoRoute(path: 'chat', builder: (_, _) => const ChatScreen()),
        GoRoute(path: 'voice', builder: (_, _) => const VoiceScreen()),
      ],
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: SafeArea(
      child: Center(
        child: FilledButton(
          onPressed: () => context.go('/'),
          child: const Text('Return to ALLY'),
        ),
      ),
    ),
  ),
);
