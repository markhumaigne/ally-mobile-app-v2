import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ally_mobile_app/core/errors/app_exception.dart';
import 'package:ally_mobile_app/models/agent_model.dart';
import 'package:ally_mobile_app/models/chat_message_model.dart';
import 'package:ally_mobile_app/providers/agent_provider.dart';
import 'package:ally_mobile_app/providers/chat_provider.dart';
import 'support/fixtures.dart';

void main() {
  testWidgets('expiry timer revokes the session and clears the conversation', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 14);
    final expiry = now.add(const Duration(seconds: 2));
    final repository = FakeAgentRepository()
      ..handler = (_) async => testSession(expiresAt: expiry);
    final agents = AgentProvider(repository, now: () => now);
    final chat = ChatProvider(FakeChatRepository(), agents);
    await agents.activate(agentId);
    await chat.send('hello');
    expect(agents.hasSession, isTrue);
    now = expiry;
    await tester.pump(const Duration(seconds: 2));
    expect(agents.session, isNull);
    expect(agents.error?.kind, ErrorKind.unauthorized);
    expect(chat.messages, isEmpty);
    chat.dispose();
    agents.dispose();
  });
  late FakeAgentRepository repository;
  late AgentProvider agents;
  setUp(() {
    repository = FakeAgentRepository();
    agents = AgentProvider(repository);
  });
  tearDown(() => agents.dispose());

  test(
    'initial, loading, success, reset and local validation transitions',
    () async {
      expect(agents.state, ActivationState.initial);
      final pending = Completer<AgentSession>();
      repository.handler = (_) => pending.future;
      final states = <ActivationState>[];
      agents.addListener(() => states.add(agents.state));
      final operation = agents.activate(agentId);
      expect(agents.isLoading, isTrue);
      await agents.activate(agentId);
      expect(repository.calls, 1);
      pending.complete(testSession());
      await operation;
      expect(agents.hasSession, isTrue);
      agents.reset();
      expect(agents.session, isNull);
      await agents.activate('bad');
      expect(states, [
        ActivationState.loading,
        ActivationState.success,
        ActivationState.initial,
        ActivationState.failure,
      ]);
      expect(repository.calls, 1);
    },
  );
  test('failure state preserves typed API errors', () async {
    repository.handler = (_) async => throw AppException.fromStatus(403);
    await agents.activate(agentId);
    expect(agents.state, ActivationState.failure);
    expect(agents.error?.kind, ErrorKind.forbidden);
    expect(agents.hasSession, isFalse);
  });
  test('reset discards an activation still in flight', () async {
    final pending = Completer<AgentSession>();
    repository.handler = (_) => pending.future;
    final operation = agents.activate(agentId);
    agents.reset();
    pending.complete(testSession());
    await operation;
    expect(agents.state, ActivationState.initial);
    expect(agents.session, isNull);
  });
  test(
    'chat shares agent, prevents duplicate sends, and resets conversation',
    () async {
      await agents.activate(agentId);
      final chatRepository = FakeChatRepository();
      final chat = ChatProvider(chatRepository, agents);
      addTearDown(chat.dispose);
      final pending = Completer<String>();
      chatRepository.handler = () => pending.future;
      final operation = chat.send('hello');
      await chat.send('second');
      expect(chatRepository.calls, 1);
      expect(chat.isSending, isTrue);
      expect(chatRepository.receivedSession, same(agents.session));
      pending.complete('reply');
      await operation;
      expect(chat.messages.map((m) => m.text), ['hello', 'reply']);
      agents.reset();
      expect(chat.messages, isEmpty);
      expect(chat.isSending, isFalse);
    },
  );
  test('late chat results cannot cross agent sessions', () async {
    await agents.activate(agentId);
    final pending = Completer<String>();
    final chat = ChatProvider(
      FakeChatRepository()..handler = () => pending.future,
      agents,
    );
    addTearDown(chat.dispose);
    final operation = chat.send('hello');
    agents.reset();
    await agents.activate(otherAgentId);
    pending.complete('old reply');
    await operation;
    expect(chat.messages, isEmpty);
  });
  test(
    'network failures are explicit; failed messages do not enter next transcript',
    () async {
      await agents.activate(agentId);
      final chatRepository = FakeChatRepository()
        ..handler = () async =>
            throw const AppException(ErrorKind.network, 'Offline');
      final chat = ChatProvider(chatRepository, agents);
      addTearDown(chat.dispose);
      await chat.send('lost');
      expect(chat.messages.single.delivery, MessageDelivery.failed);
      expect(chat.error?.kind, ErrorKind.network);
      expect(agents.hasSession, isTrue);
      chatRepository.handler = null;
      await chat.send('next');
      expect(chatRepository.receivedTranscript!.map((m) => m.text), ['next']);
    },
  );
  test(
    'unauthorized chat response revokes session and clears messages',
    () async {
      await agents.activate(agentId);
      final chat = ChatProvider(
        FakeChatRepository()
          ..handler = () async => throw AppException.fromStatus(401),
        agents,
      );
      addTearDown(chat.dispose);
      await chat.send('hello');
      expect(agents.hasSession, isFalse);
      expect(agents.error?.kind, ErrorKind.unauthorized);
      expect(chat.messages, isEmpty);
    },
  );
}
