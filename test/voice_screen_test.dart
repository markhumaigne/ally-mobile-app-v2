import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:ally_mobile_app/app.dart';
import 'package:ally_mobile_app/core/errors/app_exception.dart';
import 'package:ally_mobile_app/models/voice_session.dart';
import 'package:ally_mobile_app/models/voice_state.dart';
import 'package:ally_mobile_app/providers/agent_provider.dart';
import 'package:ally_mobile_app/providers/chat_provider.dart';
import 'package:ally_mobile_app/screens/chat/chat_screen.dart';
import 'package:ally_mobile_app/screens/home/home_screen.dart';
import 'package:ally_mobile_app/screens/voice/voice_screen.dart';
import 'package:ally_mobile_app/widgets/voice/voice_orb.dart';
import 'support/fixtures.dart';
import 'support/voice_fixtures.dart';

class OrbHarness {
  final audio = FakeVoiceAudio();
  final transport = FakeVoiceTransport();
  final repository = FakeVoiceRepository();

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      AllyApp(
        agentRepository: FakeAgentRepository(),
        chatRepository: FakeChatRepository(),
        voiceRepository: repository,
        voiceAudio: audio,
        voiceTransportFactory: () => transport,
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await transport.controller.close();
    });
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(HomeScreen));
    await context.read<AgentProvider>().activate(agentId);
    if (!context.mounted) return;
    GoRouter.of(context).go('/voice');
    await tester.pump();
    // Orb pulses continuously; use bounded pumps instead of pumpAndSettle.
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> tapControl(WidgetTester tester) async {
    final control = find.byKey(const Key('orb-session-button'));
    await tester.ensureVisible(control);
    await tester.tap(control);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  void introduction() {
    transport.controller.add(
      const VoiceEvent(
        VoiceEventKind.outputText,
        text: 'Hello from your agent.',
      ),
    );
    transport.controller.add(
      VoiceEvent(VoiceEventKind.audio, audio: Uint8List(480)),
    );
    transport.controller.add(const VoiceEvent(VoiceEventKind.turnComplete));
  }
}

void main() {
  testWidgets('orb starts on tap, introduces first, listens and stops', (
    tester,
  ) async {
    final harness = OrbHarness();
    await harness.open(tester);
    expect(find.text('Tap to start'), findsOneWidget);
    expect(find.text('Ready to start'), findsOneWidget);
    expect(
      tester.getCenter(find.byKey(const Key('orb-voice-button'))).dx,
      closeTo(tester.view.physicalSize.width / 2, 0.1),
    );
    expect(find.text('Voice preview'), findsNothing);
    expect(harness.repository.calls, 0);
    expect(harness.audio.starts, 0);
    await harness.tapControl(tester);
    expect(harness.repository.calls, 1);
    expect(harness.transport.texts, hasLength(1));
    expect(find.text('Preparing introduction…'), findsOneWidget);
    expect(
      tester.widget<VoiceOrb>(find.byType(VoiceOrb)).state,
      VoiceState.thinking,
    );
    harness.introduction();
    await tester.pump();
    expect(find.text('Introducing…'), findsOneWidget);
    expect(
      tester.widget<VoiceOrb>(find.byType(VoiceOrb)).state,
      VoiceState.speaking,
    );
    harness.audio.playing.add(false);
    await tester.pump();
    expect(find.text('Listening'), findsOneWidget);
    expect(
      tester.widget<VoiceOrb>(find.byType(VoiceOrb)).state,
      VoiceState.listening,
    );
    final orb = find.byKey(const Key('orb-voice-button'));
    await tester.ensureVisible(orb);
    await tester.tap(orb);
    await tester.pumpAndSettle();
    expect(harness.audio.stopped, isTrue);
    expect(harness.transport.closed, isTrue);
    expect(find.text('Tap to start'), findsOneWidget);
  });

  testWidgets(
    'tapping the orb starts voice; cancelling permission cannot start later',
    (tester) async {
      final harness = OrbHarness();
      harness.audio.permission = Completer<bool>();
      await harness.open(tester);
      await tester.tap(find.byKey(const Key('orb-voice-button')));
      await tester.pump();
      expect(find.text('Connecting'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await harness.tapControl(tester);
      harness.audio.permission!.complete(true);
      await tester.pumpAndSettle();
      expect(harness.repository.calls, 0);
      expect(harness.audio.starts, 0);
      expect(find.text('Tap to start'), findsOneWidget);
    },
  );

  testWidgets('permission error is visible and a new tap can retry', (
    tester,
  ) async {
    final harness = OrbHarness();
    harness.audio.allowed = false;
    await harness.open(tester);
    await harness.tapControl(tester);
    expect(
      find.textContaining('Microphone permission is off.'),
      findsOneWidget,
    );
    expect(find.text('Tap to retry'), findsOneWidget);
    expect(
      tester.widget<VoiceOrb>(find.byType(VoiceOrb)).state,
      VoiceState.error,
    );
    expect(harness.repository.calls, 0);
    harness.audio.allowed = true;
    await harness.tapControl(tester);
    expect(find.text('Preparing introduction…'), findsOneWidget);
    expect(find.textContaining('Microphone permission is off.'), findsNothing);
    expect(harness.repository.calls, 1);
  });

  testWidgets(
    'opening Chatbot stops orb audio and preserves agent and transcript',
    (tester) async {
      final harness = OrbHarness();
      await harness.open(tester);
      await harness.tapControl(tester);
      harness.introduction();
      await tester.pump();
      final context = tester.element(find.byType(VoiceScreen));
      final session = context.read<AgentProvider>().session;
      expect(
        context.read<ChatProvider>().messages.single.text,
        'Hello from your agent.',
      );
      await tester.ensureVisible(find.text('Open Chatbot'));
      await tester.tap(find.text('Open Chatbot'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.text('Hello from your agent.'), findsOneWidget);
      expect(harness.audio.stopped, isTrue);
      expect(harness.transport.closed, isTrue);
      expect(
        tester.element(find.byType(ChatScreen)).read<AgentProvider>().session,
        same(session),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final exit in ['back', 'system back', 'background', 'agent reset']) {
    testWidgets('$exit stops the orb session', (tester) async {
      final harness = OrbHarness();
      await harness.open(tester);
      await harness.tapControl(tester);
      switch (exit) {
        case 'back':
          await tester.tap(find.byTooltip('Back to assistants'));
        case 'system back':
          await tester.binding.handlePopRoute();
        case 'agent reset':
          tester
              .element(find.byType(VoiceScreen))
              .read<AgentProvider>()
              .reset();
        case 'background':
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.hidden,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
      }
      await tester.pumpAndSettle();
      expect(harness.audio.stopped, isTrue);
      expect(harness.transport.closed, isTrue);
      if (exit == 'background') {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(
          harness.repository.calls,
          1,
          reason: 'resume must not restart voice',
        );
        expect(find.text('Tap to start'), findsOneWidget);
      } else {
        expect(find.byType(HomeScreen), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(320, 640), const Size(800, 600)]) {
    testWidgets(
      'orb controls and errors fit ${size.width} width at large text',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final harness = OrbHarness();
        harness.repository.failure = const AppException(
          ErrorKind.voice,
          'The assistant could not connect. Please try again.',
        );
        await harness.open(tester, size: size);
        await harness.tapControl(tester);
        expect(find.text('Tap to retry'), findsOneWidget);
        expect(
          find.textContaining('The assistant could not connect.'),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Open Chatbot'));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
