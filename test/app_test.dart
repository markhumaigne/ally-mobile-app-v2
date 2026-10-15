import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ally_mobile_app/app.dart';
import 'package:ally_mobile_app/core/config/app_config.dart';
import 'package:ally_mobile_app/core/errors/app_exception.dart';
import 'package:ally_mobile_app/models/agent_model.dart';
import 'package:ally_mobile_app/models/voice_session.dart';
import 'package:ally_mobile_app/providers/agent_provider.dart';
import 'package:ally_mobile_app/repositories/agent_repository.dart';
import 'package:ally_mobile_app/repositories/chat_repository.dart';
import 'package:ally_mobile_app/services/api_service.dart';
import 'package:ally_mobile_app/screens/chat/chat_screen.dart';
import 'package:ally_mobile_app/screens/home/home_screen.dart';
import 'package:ally_mobile_app/screens/splash/splash_screen.dart';
import 'package:ally_mobile_app/screens/voice/voice_screen.dart';
import 'support/fixtures.dart';
import 'support/voice_fixtures.dart';
import 'package:ally_mobile_app/providers/voice_provider.dart';

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
    ChatRepository? chatRepository,
    FakeVoiceRepository? voiceRepository,
    FakeVoiceAudio? voiceAudio,
    FakeVoiceTransport? voiceTransport,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      AllyApp(
        agentRepository: agents,
        chatRepository: chatRepository ?? FakeChatRepository(),
        voiceRepository: voiceRepository,
        voiceAudio: voiceAudio,
        voiceTransportFactory: voiceTransport == null
            ? null
            : () => voiceTransport,
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
    'Home exit releases audio and closes Android without activation',
    (tester) async {
      final audio = FakeVoiceAudio();
      final agents = FakeAgentRepository();
      var exits = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.pop') {
            expect(audio.stopped, isTrue);
            exits++;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await launch(tester, agents, voiceAudio: audio);
      final exitButton = find.byKey(const Key('exit-app-button'));
      expect(find.text('Exit'), findsOneWidget);
      await Scrollable.ensureVisible(
        tester.element(find.text('Exit')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(exitButton);
      await tester.pumpAndSettle();
      expect(exits, 1);
      expect(agents.calls, 0);
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.text('Enter your Agent UUID.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selection Back returns to the UUID form without exiting or showing splash',
    (tester) async {
      var exits = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.pop') exits++;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await launch(tester, FakeAgentRepository());
      await activate(tester);
      expect(find.text('Exit'), findsNothing);
      expect(find.byKey(const Key('exit-app-button')), findsNothing);
      expect(find.text('Change Agent UUID'), findsNothing);
      expect(find.text('Back'), findsOneWidget);
      await Scrollable.ensureVisible(
        tester.element(find.text('Back')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('back-to-agent-form-button')));
      await tester.pump();
      expect(find.byType(SplashScreen), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-card')), findsNothing);
      expect(find.byKey(const Key('back-to-agent-form-button')), findsNothing);
      expect(find.text('Exit'), findsOneWidget);
      expect(exits, 0);
      final context = tester.element(find.byType(HomeScreen));
      expect(context.read<AgentProvider>().hasSession, isFalse);
      final input = tester.widget<TextFormField>(
        find.byKey(const Key('agent-id')),
      );
      expect(input.controller!.text, agentId);
      expect(
        tester
            .widget<CustomScrollView>(find.byType(CustomScrollView))
            .controller!
            .offset,
        0,
      );
      expect(find.text('Launch Your\nAI Agent').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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
    'active public API response unlocks modes and sends chat without a token',
    (tester) async {
      final payload = activationPayload();
      payload['data']['subscriptions'] = null;
      payload.remove('embedToken');
      payload.remove('embedTokenExpiresAt');
      const config = AppConfig(apiBaseUrl: 'https://example.test/api/v1');
      var chatCalls = 0;
      final api = ApiService(
        config: config,
        client: MockClient((request) async {
          expect(request.headers.containsKey('Authorization'), isFalse);
          if (request.method == 'GET') {
            return http.Response(jsonEncode(payload), 200);
          }
          chatCalls++;
          expect(jsonDecode(request.body)['receptionistId'], agentId);
          return http.Response(jsonEncode({'text': 'Public chat works'}), 200);
        }),
      );
      addTearDown(api.close);
      await tester.pumpWidget(
        AllyApp(
          config: config,
          agentRepository: ApiAgentRepository(api),
          chatRepository: ApiChatRepository(api),
        ),
      );
      await tester.pumpAndSettle();
      await activate(tester);
      expect(find.text('Agent active'), findsOneWidget);
      expect(find.text('Subscription active'), findsNothing);
      expect(find.byKey(const Key('chat-card')), findsOneWidget);
      expect(find.byKey(const Key('voice-card')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('chat-card')));
      await tester.tap(find.byKey(const Key('chat-card')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('chat-input')), 'Hello');
      await tester.pump();
      await tester.tap(find.byKey(const Key('send-button')));
      await tester.pumpAndSettle();
      expect(find.text('Public chat works'), findsOneWidget);
      expect(chatCalls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'activation unlocks both modes; chat works with test repository; reset protects routes',
    (tester) async {
      await launch(tester, FakeAgentRepository());
      await activate(tester);
      expect(find.text('Agent active'), findsOneWidget);
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
      expect(find.text('Voice preview'), findsNothing);
      expect(find.text('Tap to start'), findsOneWidget);
      final context = tester.element(find.byType(VoiceScreen));
      expect(context.read<AgentProvider>().session!.agent.id, agentId);
      context.read<AgentProvider>().reset();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byKey(const Key('chat-card')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'voice control starts, backgrounding stops capture, text still works',
    (tester) async {
      final audio = FakeVoiceAudio();
      final transport = FakeVoiceTransport();
      addTearDown(transport.controller.close);
      await launch(
        tester,
        FakeAgentRepository(),
        voiceRepository: FakeVoiceRepository(),
        voiceAudio: audio,
        voiceTransport: transport,
      );
      await activate(tester);
      await tester.ensureVisible(find.byKey(const Key('chat-card')));
      await tester.tap(find.byKey(const Key('chat-card')));
      await tester.pumpAndSettle();
      expect(find.text('Welcome'), findsOneWidget);
      expect(find.byTooltip('Start voice'), findsOneWidget);
      await tester.tap(find.byKey(const Key('voice-button')));
      await tester.pumpAndSettle();
      expect(find.text('Preparing introduction…'), findsOneWidget);
      expect(find.text('Listening'), findsNothing);
      expect(audio.starts, 1);
      expect(transport.texts, hasLength(1));
      transport.controller.add(
        const VoiceEvent(
          VoiceEventKind.outputText,
          text: 'Hello, how can I help?',
        ),
      );
      transport.controller.add(
        VoiceEvent(VoiceEventKind.audio, audio: Uint8List(480)),
      );
      transport.controller.add(const VoiceEvent(VoiceEventKind.turnComplete));
      await tester.pumpAndSettle();
      expect(find.text('Hello, how can I help?'), findsOneWidget);
      expect(find.text('Introducing…'), findsOneWidget);
      expect(find.text('Listening'), findsNothing);
      audio.playing.add(false);
      await tester.pumpAndSettle();
      expect(find.text('Listening'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(audio.stopped, isTrue);
      expect(transport.closed, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('chat-input')), 'Hello');
      await tester.pump();
      await tester.tap(find.byKey(const Key('send-button')));
      await tester.pumpAndSettle();
      expect(find.text('Test response'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('leaving chat stops voice and releases its connection', (
    tester,
  ) async {
    final audio = FakeVoiceAudio();
    final transport = FakeVoiceTransport();
    addTearDown(transport.controller.close);
    await launch(
      tester,
      FakeAgentRepository(),
      voiceRepository: FakeVoiceRepository(),
      voiceAudio: audio,
      voiceTransport: transport,
    );
    await activate(tester);
    await tester.ensureVisible(find.byKey(const Key('chat-card')));
    await tester.tap(find.byKey(const Key('chat-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('voice-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back to assistants'));
    await tester.pumpAndSettle();
    expect(audio.stopped, isTrue);
    expect(transport.closed, isTrue);
    final context = tester.element(find.byType(HomeScreen));
    expect(context.read<VoiceProvider>().connected, isFalse);
  });

  testWidgets(
    'HTTP-200 backend failure retains message and can be edited without auto retry',
    (tester) async {
      var calls = 0;
      final api = ApiService(
        config: const AppConfig(apiBaseUrl: 'https://example.test/api/v1'),
        client: MockClient((request) async {
          calls++;
          return http.Response(
            jsonEncode({
              'text':
                  'Sorry, I am having trouble connecting right now. Please try again later.',
            }),
            200,
          );
        }),
      );
      addTearDown(api.close);
      await launch(
        tester,
        FakeAgentRepository(),
        chatRepository: ApiChatRepository(api),
      );
      await activate(tester);
      await tester.ensureVisible(find.byKey(const Key('chat-card')));
      await tester.tap(find.byKey(const Key('chat-card')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('chat-input')),
        'My follow-up',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('send-button')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Your assistant is temporarily unavailable.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Sorry, I am having trouble connecting right now. Please try again later.',
        ),
        findsNothing,
      );
      expect(find.text('My follow-up'), findsOneWidget);
      await tester.tap(find.byKey(const Key('edit-failed-message')));
      await tester.pump();
      final input = tester.widget<TextField>(
        find.byKey(const Key('chat-input')),
      );
      expect(input.controller!.text, 'My follow-up');
      expect(calls, 1);
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
    testWidgets(
      'chat composer and voice button fit ${size.width} width with keyboard',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.view.resetViewInsets);
        await launch(tester, FakeAgentRepository(), size: size);
        await activate(tester);
        await Scrollable.ensureVisible(
          tester.element(find.text('Chatbot')),
          alignment: 0.5,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chatbot'));
        await tester.pumpAndSettle();
        expect(find.byType(ChatScreen), findsOneWidget);
        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('voice-button')), findsOneWidget);
        await tester.enterText(find.byKey(const Key('chat-input')), 'Hello');
        await tester.pump();
        expect(find.byKey(const Key('send-button')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

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
