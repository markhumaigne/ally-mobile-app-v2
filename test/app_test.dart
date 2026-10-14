import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:ally_mobile_app/app.dart';
import 'package:ally_mobile_app/core/config/app_config.dart';
import 'package:ally_mobile_app/core/errors/app_exception.dart';
import 'package:ally_mobile_app/models/agent_model.dart';
import 'package:ally_mobile_app/providers/agent_provider.dart';
import 'package:ally_mobile_app/screens/chat/chat_screen.dart';
import 'package:ally_mobile_app/screens/home/home_screen.dart';
import 'package:ally_mobile_app/screens/splash/splash_screen.dart';
import 'package:ally_mobile_app/screens/voice/voice_screen.dart';
import 'support/fixtures.dart';

void main() {
  testWidgets('slow first frame cannot consume the blue screen display time', (
    tester,
  ) async {
    final firstFrame = Completer<void>();
    await tester.pumpWidget(
      AllyApp(
        agentRepository: FakeAgentRepository(),
        chatRepository: FakeChatRepository(),
        firstFrameReady: firstFrame.future,
      ),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    firstFrame.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  Future<void> launch(
    WidgetTester tester,
    FakeAgentRepository agents, {
    String location = '/splash',
    Size size = const Size(400, 850),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      AllyApp(
        agentRepository: agents,
        chatRepository: FakeChatRepository(),
        config: const AppConfig(apiBaseUrl: 'https://example.test/api/v1'),
        initialLocation: location,
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
  }

  Future<void> activate(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('agent-id')), agentId);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('activate-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activate-button')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'blue splash stays visible for two seconds, then Home validates form',
    (tester) async {
      final agents = FakeAgentRepository();
      await tester.pumpWidget(
        AllyApp(agentRepository: agents, chatRepository: FakeChatRepository()),
      );
      expect(find.byType(SplashScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1900));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('ALLY'), findsOneWidget);
      expect(find.text('Created by HumAIn PH'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('activate-button')));
      await tester.tap(find.byKey(const Key('activate-button')));
      await tester.pumpAndSettle();
      expect(find.text('Enter your Agent UUID.'), findsOneWidget);
      expect(agents.calls, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('reduced motion keeps the blue intro visible before Home', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      AllyApp(
        agentRepository: FakeAgentRepository(),
        chatRepository: FakeChatRepository(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.text('Created by HumAIn PH'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('disposing before the first frame cancels startup safely', (
    tester,
  ) async {
    final firstFrame = Completer<void>();
    await tester.pumpWidget(
      AllyApp(
        agentRepository: FakeAgentRepository(),
        chatRepository: FakeChatRepository(),
        firstFrameReady: firstFrame.future,
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    firstFrame.complete();
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Home shows loading, prevents duplicate activation, and displays failure',
    (tester) async {
      final pending = Completer<AgentSession>();
      final agents = FakeAgentRepository()..handler = (_) => pending.future;
      await launch(tester, agents);
      await tester.enterText(find.byKey(const Key('agent-id')), agentId);
      await tester.enterText(
        find.byKey(const Key('user-id')),
        'optional-reference',
      );
      await tester.ensureVisible(find.byKey(const Key('activate-button')));
      await tester.tap(find.byKey(const Key('activate-button')));
      await tester.pump();
      expect(find.text('Validating agent…'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('activate-button')))
            .onPressed,
        isNull,
      );
      pending.completeError(AppException.fromStatus(403));
      await tester.pumpAndSettle();
      expect(find.text('Access to this agent was denied.'), findsOneWidget);
      expect(find.byKey(const Key('chat-card')), findsNothing);
      expect(agents.userReference, 'optional-reference');
    },
  );

  for (final route in ['/chat', '/voice']) {
    testWidgets('$route is protected on deep link and after initialization', (
      tester,
    ) async {
      await launch(tester, FakeAgentRepository(), location: route);
      expect(find.byType(HomeScreen), findsOneWidget);
      GoRouter.of(tester.element(find.byType(HomeScreen))).go(route);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(ChatScreen), findsNothing);
      expect(find.byType(VoiceScreen), findsNothing);
    });
  }

  testWidgets(
    'activation unlocks both modes; chat works with test repository; reset protects routes',
    (tester) async {
      await launch(tester, FakeAgentRepository());
      await activate(tester);
      expect(find.text('Subscription active'), findsOneWidget);
      expect(find.text('Test Concierge'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('chat-card')));
      await tester.tap(find.byKey(const Key('chat-card')));
      await tester.pumpAndSettle();
      expect(find.byType(ChatScreen), findsOneWidget);
      await tester.enterText(find.byKey(const Key('chat-input')), 'Hello');
      await tester.pump();
      await tester.tap(find.byKey(const Key('send-button')));
      await tester.pumpAndSettle();
      expect(find.text('Test response'), findsOneWidget);
      await tester.tap(find.byTooltip('Back to assistants'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('voice-card')));
      await tester.tap(find.byKey(const Key('voice-card')));
      // The orb animates continuously; do not pumpAndSettle on this screen.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(VoiceScreen), findsOneWidget);
      expect(find.text('Voice preview'), findsOneWidget);
      expect(find.text('Tap to start'), findsNothing);
      final context = tester.element(find.byType(VoiceScreen));
      expect(context.read<AgentProvider>().session!.agent.id, agentId);
      context.read<AgentProvider>().reset();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byKey(const Key('chat-card')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('revoking a session protects the chat route', (tester) async {
    final agents = FakeAgentRepository()
      ..handler = (_) async => testSession(
        expiresAt: DateTime.now().add(const Duration(seconds: 1)),
      );
    await launch(tester, agents);
    await activate(tester);
    // Timer callback uses wall clock in production. Simulate expiry explicitly
    // with a deterministic expired session before activating a protected route.
    final context = tester.element(find.byType(HomeScreen));
    final provider = context.read<AgentProvider>();
    provider.invalidate(AppException.fromStatus(401));
    GoRouter.of(context).go('/chat');
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(provider.hasSession, isFalse);
  });

  for (final size in [const Size(320, 640), const Size(800, 600)]) {
    testWidgets('form and selection fit ${size.width} width at large text', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await launch(tester, FakeAgentRepository(), size: size);
      expect(tester.takeException(), isNull);
      await activate(tester);
      expect(find.byKey(const Key('voice-card')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
