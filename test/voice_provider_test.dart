import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ally_mobile_app/core/errors/app_exception.dart';
import 'package:ally_mobile_app/models/chat_message_model.dart';
import 'package:ally_mobile_app/models/voice_session.dart';
import 'package:ally_mobile_app/models/voice_state.dart';
import 'package:ally_mobile_app/providers/agent_provider.dart';
import 'package:ally_mobile_app/providers/chat_provider.dart';
import 'package:ally_mobile_app/providers/voice_provider.dart';
import 'support/fixtures.dart';
import 'support/voice_fixtures.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

Future<void> finishIntroduction(
  FakeVoiceTransport transport,
  FakeVoiceAudio audio,
) async {
  transport.controller.add(
    VoiceEvent(VoiceEventKind.audio, audio: Uint8List(480)),
  );
  transport.controller.add(const VoiceEvent(VoiceEventKind.turnComplete));
  await flush();
  audio.playing.add(false);
  await flush();
}

void main() {
  late AgentProvider agents;
  late ChatProvider chat;
  late VoiceProvider voice;
  late FakeVoiceRepository repository;
  late FakeVoiceAudio audio;
  late FakeVoiceTransport transport;
  void useShortIntroductionTimeout() {
    voice.dispose();
    unawaited(transport.controller.close());
    audio = FakeVoiceAudio();
    transport = FakeVoiceTransport();
    voice = VoiceProvider(
      repository,
      agents,
      chat,
      audio: audio,
      transportFactory: () => transport,
      introductionTimeout: const Duration(milliseconds: 10),
    );
  }

  setUp(() async {
    agents = AgentProvider(FakeAgentRepository());
    await agents.activate(agentId);
    chat = ChatProvider(FakeChatRepository(), agents);
    repository = FakeVoiceRepository();
    audio = FakeVoiceAudio();
    transport = FakeVoiceTransport();
    voice = VoiceProvider(
      repository,
      agents,
      chat,
      audio: audio,
      transportFactory: () => transport,
    );
  });
  tearDown(() async {
    await voice.stop();
    voice.dispose();
    chat.dispose();
    agents.dispose();
    await flush();
    await transport.controller.close();
  });

  test(
    'denied microphone never requests a credential; text remains usable',
    () async {
      audio.allowed = false;
      await voice.start();
      expect(voice.error?.kind, ErrorKind.microphone);
      expect(repository.calls, 0);
      expect(audio.starts, 0);
      await chat.send('Hello');
      expect(chat.messages.last.text, 'Test response');
      expect(agents.hasSession, isTrue);
    },
  );

  test(
    'duplicate start and stop during permission prompt cannot open microphone later',
    () async {
      audio.permission = Completer<bool>();
      final start = voice.start();
      await flush();
      await voice.start();
      await voice.stop();
      audio.permission!.complete(true);
      await start;
      expect(repository.calls, 0);
      expect(audio.starts, 0);
      expect(voice.connected, isFalse);
    },
  );

  test(
    'agent change while credential is loading discards the old credential',
    () async {
      repository.pending = Completer<VoiceSession>();
      final start = voice.start();
      await flush();
      agents.reset();
      repository.pending!.complete(voiceCredential());
      await start;
      expect(audio.starts, 0);
      expect(voice.connected, isFalse);
      expect(chat.messages, isEmpty);
    },
  );

  test(
    'stop during socket setup closes transport and never starts capture',
    () async {
      transport.pending = Completer<void>();
      final start = voice.start();
      await flush();
      await voice.stop();
      transport.pending!.complete();
      await start;
      expect(transport.closed, isTrue);
      expect(audio.starts, 0);
      expect(transport.texts, isEmpty);
    },
  );

  test(
    'agent speaks first; microphone and typed turns wait for playback',
    () async {
      await voice.start();
      await voice.start();
      expect(transport.texts, hasLength(1));
      expect(transport.texts.single, contains('configured name and role'));
      expect(voice.statusLabel, 'Preparing introduction…');
      expect(chat.messages, isEmpty, reason: 'the cue is not a user message');
      audio.input.add(Uint8List(320));
      voice.sendText('Too soon');
      await flush();
      expect(transport.audioChunks, 0);
      expect(transport.texts, hasLength(1));

      transport.controller.add(
        const VoiceEvent(
          VoiceEventKind.outputText,
          text: 'Hello, I am your assistant.',
        ),
      );
      transport.controller.add(
        VoiceEvent(VoiceEventKind.audio, audio: Uint8List(480)),
      );
      transport.controller.add(const VoiceEvent(VoiceEventKind.turnComplete));
      await flush();
      expect(voice.statusLabel, 'Introducing…');
      expect(voice.canSendText, isFalse);
      audio.input.add(Uint8List(320));
      await flush();
      expect(transport.audioChunks, 0);
      expect(chat.messages.single.role, MessageRole.assistant);
      expect(chat.messages.single.text, 'Hello, I am your assistant.');

      audio.playing.add(false);
      await flush();
      expect(voice.state, VoiceState.listening);
      expect(voice.canSendText, isTrue);
      audio.input.add(Uint8List(320));
      await flush();
      expect(transport.audioChunks, 1);
    },
  );

  test(
    'playback draining between chunks cannot end the introduction early',
    () async {
      await voice.start();
      transport.controller.add(
        VoiceEvent(VoiceEventKind.audio, audio: Uint8List(480)),
      );
      await flush();
      audio.playing.add(false);
      await flush();
      audio.input.add(Uint8List(320));
      await flush();
      expect(voice.state, VoiceState.speaking);
      expect(transport.audioChunks, 0);
      transport.controller.add(const VoiceEvent(VoiceEventKind.turnComplete));
      await flush();
      expect(voice.state, VoiceState.listening);
    },
  );

  test(
    'queued speaker work must finish before opening the microphone stream',
    () async {
      audio.pendingPlay = Completer<void>();
      await voice.start();
      transport.controller.add(
        VoiceEvent(VoiceEventKind.audio, audio: Uint8List(480)),
      );
      transport.controller.add(const VoiceEvent(VoiceEventKind.turnComplete));
      await flush();
      audio.playing.add(false);
      await flush();
      audio.input.add(Uint8List(320));
      await flush();
      expect(voice.state, VoiceState.speaking);
      expect(transport.audioChunks, 0);
      audio.pendingPlay!.complete();
      await flush();
      expect(voice.state, VoiceState.listening);
    },
  );

  test(
    'empty opening response fails clearly and keeps text available',
    () async {
      await voice.start();
      transport.controller.add(const VoiceEvent(VoiceEventKind.turnComplete));
      await flush();
      expect(
        voice.error?.message,
        contains('could not speak its introduction'),
      );
      expect(audio.stopped, isTrue);
      expect(transport.closed, isTrue);
      expect(voice.canSendText, isTrue);
      expect(agents.hasSession, isTrue);
    },
  );

  test('an unanswered introduction times out and releases recording', () async {
    useShortIntroductionTimeout();
    await voice.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(voice.state, VoiceState.error);
    expect(voice.error?.message, contains('introduction did not finish'));
    expect(audio.stopped, isTrue);
    expect(transport.closed, isTrue);
    expect(voice.canSendText, isTrue);
    expect(agents.hasSession, isTrue);
  });

  test('stop cancels the opening timer and ignores late audio', () async {
    useShortIntroductionTimeout();
    await voice.start();
    await voice.stop();
    transport.controller.add(
      VoiceEvent(VoiceEventKind.audio, audio: Uint8List(480)),
    );
    transport.controller.add(
      const VoiceEvent(VoiceEventKind.outputText, text: 'late introduction'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(voice.state, VoiceState.disconnected);
    expect(audio.samples, 0);
    expect(chat.messages, isEmpty);
    expect(voice.error, isNull);
  });

  test('opening greeting cannot execute appointment actions', () async {
    await voice.start();
    transport.controller.add(
      const VoiceEvent(
        VoiceEventKind.toolCall,
        call: VoiceToolCall('opening-call', 'check_appointments', {}),
      ),
    );
    await flush();
    expect(repository.toolCalls, 0);
    expect(transport.toolResponses, 1);
    expect(voice.statusLabel, 'Preparing introduction…');
  });

  test(
    'voice shares text history, streams transcripts and waits for playback to drain',
    () async {
      await chat.send('Hello');
      await voice.start();
      expect(transport.history, hasLength(2));
      expect(transport.texts.single, contains('welcome the user back'));
      await finishIntroduction(transport, audio);
      expect(voice.state, VoiceState.listening);
      audio.input.add(Uint8List(320));
      await flush();
      expect(transport.audioChunks, 1);
      transport.controller.add(
        const VoiceEvent(VoiceEventKind.inputText, text: 'How '),
      );
      transport.controller.add(
        const VoiceEvent(VoiceEventKind.inputText, text: 'are you?'),
      );
      transport.controller.add(
        const VoiceEvent(VoiceEventKind.outputText, text: 'I am '),
      );
      transport.controller.add(
        const VoiceEvent(VoiceEventKind.outputText, text: 'well.'),
      );
      transport.controller.add(
        VoiceEvent(VoiceEventKind.audio, audio: Uint8List(480)),
      );
      transport.controller.add(const VoiceEvent(VoiceEventKind.turnComplete));
      await flush();
      expect(chat.messages.map((m) => m.text).toList(), [
        'Hello',
        'Test response',
        'How are you?',
        'I am well.',
      ]);
      expect(voice.state, VoiceState.speaking);
      expect(audio.samples, 480);
      audio.input.add(Uint8List(320));
      await flush();
      expect(
        transport.audioChunks,
        1,
        reason: 'speaker echo must not be sent to the model',
      );
      audio.playing.add(false);
      await flush();
      expect(voice.state, VoiceState.listening);
      voice.sendText('Thanks');
      expect(transport.texts, hasLength(2));
      expect(transport.texts.last, 'Thanks');
      expect(chat.messages.last.text, 'Thanks');
      expect(voice.state, VoiceState.thinking);
      await voice.stop();
      expect(transport.closed, isTrue);
      expect(audio.stopped, isTrue);
      expect(chat.messages, hasLength(5));
    },
  );

  test(
    'interruption flushes speaker audio and late events after reset are ignored',
    () async {
      await voice.start();
      await finishIntroduction(transport, audio);
      transport.controller.add(const VoiceEvent(VoiceEventKind.interrupted));
      await flush();
      expect(audio.interrupts, 1);
      agents.reset();
      transport.controller.add(
        const VoiceEvent(VoiceEventKind.outputText, text: 'stale'),
      );
      await flush();
      expect(chat.messages, isEmpty);
      expect(audio.stopped, isTrue);
    },
  );

  test(
    'tool replay is not executed twice; cancelled responses are discarded',
    () async {
      await voice.start();
      await finishIntroduction(transport, audio);
      repository.pendingTool = Completer<Map<String, dynamic>>();
      const call = VoiceToolCall('test-call', 'check_appointments', {
        'date': '2026-10-16',
      });
      transport.controller.add(
        const VoiceEvent(VoiceEventKind.toolCall, call: call),
      );
      transport.controller.add(
        const VoiceEvent(VoiceEventKind.toolCall, call: call),
      );
      await flush();
      expect(repository.toolCalls, 1);
      transport.controller.add(
        const VoiceEvent(VoiceEventKind.toolCancelled, text: 'test-call'),
      );
      await flush();
      repository.pendingTool!.complete({'success': true});
      await flush();
      expect(transport.toolResponses, 0);
    },
  );

  test(
    'backend denial revokes session; socket failure only stops voice',
    () async {
      await voice.start();
      transport.controller.add(
        const VoiceEvent(
          VoiceEventKind.failed,
          error: AppException(ErrorKind.voice, 'Disconnected'),
        ),
      );
      await flush();
      await flush();
      expect(voice.state, VoiceState.error);
      expect(audio.stopped, isTrue);
      expect(agents.hasSession, isTrue);
      repository.failure = AppException.fromStatus(403);
      await voice.start();
      expect(agents.hasSession, isFalse);
      expect(agents.error?.kind, ErrorKind.forbidden);
    },
  );
}
