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
      'rejects non-active subscription $status even if agent is active',
      () async {
        payload['data']['subscriptions']['status'] = status;
        await expectLater(
          ApiAgentRepository(api).activate(agentId),
          throwsA(
            isA<AppException>().having(
              (e) => e.kind,
              'kind',
              ErrorKind.inactiveSubscription,
            ),
          ),
        );
      },
    );
  }
  test(
    'fails closed for live deployment shape: no subscription and no session token',
    () async {
      payload['data']['subscriptions'] = null;
      payload.remove('embedToken');
      payload.remove('embedTokenExpiresAt');
      await expectLater(
        ApiAgentRepository(api).activate(agentId),
        throwsA(
          isA<AppException>().having(
            (e) => e.kind,
            'kind',
            ErrorKind.subscriptionUnverified,
          ),
        ),
      );
    },
  );
  test('requires a usable token in addition to active status', () async {
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
