import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ally_mobile_app/core/config/app_config.dart';
import 'package:ally_mobile_app/core/errors/app_exception.dart';
import 'package:ally_mobile_app/models/chat_message_model.dart';
import 'package:ally_mobile_app/repositories/agent_repository.dart';
import 'package:ally_mobile_app/repositories/chat_repository.dart';
import 'package:ally_mobile_app/services/api_service.dart';
import 'support/fixtures.dart';

void main() {
  late Map<String, dynamic> payload;
  late ApiService api;
  late http.Request captured;
  setUp(() {
    payload = activationPayload();
    api = ApiService(
      config: const AppConfig(apiBaseUrl: 'https://example.test/api/v1'),
      client: MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode(payload), 200);
      }),
    );
  });
  tearDown(() => api.close());

  test(
    'activation uses verified GET contract and does not transmit optional user ID',
    () async {
      final session = await ApiAgentRepository(
        api,
      ).activate(agentId, userReference: 'local-reference');
      expect(session.agent.id, agentId);
      expect(session.agent.name, 'Test Concierge');
      expect(session.userReference, 'local-reference');
      expect(captured.method, 'GET');
      expect(captured.url.path, '/api/v1/embed/config/$agentId');
      expect(captured.url.query, isEmpty);
      expect(captured.body, isEmpty);
      expect(captured.headers.containsKey('Authorization'), isFalse);
    },
  );

  for (final status in ['inactive', 'pending', 'blocked', 'deleted']) {
    test('rejects $status agent', () async {
      payload['data']['status'] = status;
      await expectLater(
        ApiAgentRepository(api).activate(agentId),
        throwsA(
          isA<AppException>().having(
            (e) => e.kind,
            'kind',
            ErrorKind.inactiveAgent,
          ),
        ),
      );
    });
  }
  for (final status in ['past_due', 'unpaid', 'cancelled', 'incomplete']) {
    test(
      'active agent can activate with optional subscription status $status',
      () async {
        payload['data']['subscriptions']['status'] = status;
        final session = await ApiAgentRepository(api).activate(agentId);
        expect(session.agent.subscriptionStatus, status);
        expect(session.isValidAt(DateTime.now()), isTrue);
      },
    );
  }
  test(
    'activates live deployment shape without subscription or session token',
    () async {
      payload['data']['subscriptions'] = null;
      payload.remove('embedToken');
      payload.remove('embedTokenExpiresAt');
      final session = await ApiAgentRepository(api).activate(agentId);
      expect(session.agent.subscriptionStatus, isNull);
      expect(session.embedToken, isNull);
      expect(session.expiresAt, isNull);
      expect(session.isValidAt(DateTime.now()), isTrue);
    },
  );
  test(
    'partial session credentials cannot become an anonymous session',
    () async {
      payload.remove('embedToken');
      await expectLater(
        ApiAgentRepository(api).activate(agentId),
        throwsA(
          isA<AppException>().having(
            (e) => e.kind,
            'kind',
            ErrorKind.unauthorized,
          ),
        ),
      );
    },
  );
  test('missing optional fields and explicit nulls both activate', () async {
    payload['data'].remove('subscriptions');
    payload['embedToken'] = null;
    payload['embedTokenExpiresAt'] = null;
    final session = await ApiAgentRepository(api).activate(agentId);
    expect(session.agent.subscriptionStatus, isNull);
    expect(session.embedToken, isNull);
    expect(session.expiresAt, isNull);
  });
  for (final invalidToken in ['', 'bad token', 123]) {
    test('rejects malformed supplied token $invalidToken', () async {
      payload['embedToken'] = invalidToken;
      await expectLater(
        ApiAgentRepository(api).activate(agentId),
        throwsA(
          isA<AppException>().having(
            (e) => e.kind,
            'kind',
            ErrorKind.unauthorized,
          ),
        ),
      );
    });
  }
  test('supplied token still requires its expiry', () async {
    payload.remove('embedTokenExpiresAt');
    await expectLater(
      ApiAgentRepository(api).activate(agentId),
      throwsA(
        isA<AppException>().having(
          (e) => e.kind,
          'kind',
          ErrorKind.unauthorized,
        ),
      ),
    );
  });
  test('rejects expired sessions and mismatched agent metadata', () async {
    payload['embedTokenExpiresAt'] = 1;
    await expectLater(
      ApiAgentRepository(api).activate(agentId),
      throwsA(isA<AppException>()),
    );
    payload = activationPayload();
    payload['data']['id'] = otherAgentId;
    await expectLater(
      ApiAgentRepository(api).activate(agentId),
      throwsA(
        isA<AppException>().having(
          (e) => e.kind,
          'kind',
          ErrorKind.unexpectedResponse,
        ),
      ),
    );
  });
  test(
    'chat uses the real non-streaming text contract and bearer session',
    () async {
      payload = {'text': 'Hello from test'};
      const message = ChatMessageModel(
        id: 1,
        role: MessageRole.user,
        text: 'Hello',
      );
      final result = await ApiChatRepository(
        api,
      ).send(session: testSession(), transcript: [message], text: 'Hello');
      expect(result, 'Hello from test');
      expect(captured.url.path, '/api/v1/embed/text-message');
      expect(captured.headers['Authorization'], 'Bearer test-only-session');
      expect(jsonDecode(captured.body), {
        'receptionistId': agentId,
        'transcript': [
          {'sender': 'user', 'text': 'Hello'},
        ],
        'userMessage': 'Hello',
      });
    },
  );
  test(
    'public chat omits Authorization and keeps the real request contract',
    () async {
      payload = {'text': 'Public test reply'};
      final result = await ApiChatRepository(api).send(
        session: publicTestSession(),
        transcript: const [
          ChatMessageModel(id: 1, role: MessageRole.user, text: 'Hello'),
        ],
        text: 'Hello',
      );
      expect(result, 'Public test reply');
      expect(captured.headers.containsKey('Authorization'), isFalse);
      expect(jsonDecode(captured.body), {
        'receptionistId': agentId,
        'transcript': [
          {'sender': 'user', 'text': 'Hello'},
        ],
        'userMessage': 'Hello',
      });
    },
  );
  test(
    'server rejection is preserved without retrying or dropping the token',
    () async {
      var calls = 0;
      final rejectingApi = ApiService(
        config: const AppConfig(apiBaseUrl: 'https://example.test/api/v1'),
        client: MockClient((request) async {
          calls++;
          expect(request.headers['Authorization'], 'Bearer test-only-session');
          return http.Response('{}', 401);
        }),
      );
      addTearDown(rejectingApi.close);
      await expectLater(
        ApiChatRepository(
          rejectingApi,
        ).send(session: testSession(), transcript: [], text: 'Hello'),
        throwsA(
          isA<AppException>().having(
            (e) => e.kind,
            'kind',
            ErrorKind.unauthorized,
          ),
        ),
      );
      expect(calls, 1);
    },
  );
  test(
    'rejects empty chat replies rather than inventing an assistant answer',
    () async {
      payload = {'text': ''};
      await expectLater(
        ApiChatRepository(
          api,
        ).send(session: testSession(), transcript: [], text: 'Hello'),
        throwsA(
          isA<AppException>().having(
            (e) => e.kind,
            'kind',
            ErrorKind.unexpectedResponse,
          ),
        ),
      );
    },
  );
}
