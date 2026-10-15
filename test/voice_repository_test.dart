import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ally_mobile_app/core/config/app_config.dart';
import 'package:ally_mobile_app/core/errors/app_exception.dart';
import 'package:ally_mobile_app/models/voice_session.dart';
import 'package:ally_mobile_app/repositories/voice_repository.dart';
import 'package:ally_mobile_app/repositories/chat_repository.dart';
import 'package:ally_mobile_app/services/api_service.dart';
import 'support/fixtures.dart';

void main() {
  late Map<String, dynamic> payload;
  late http.Request captured;
  late ApiService api;
  setUp(() {
    final now = DateTime.now().millisecondsSinceEpoch;
    payload = {
      'token': 'auth_tokens/test-only',
      'voiceModel': 'test-model',
      'expiry': now + 1800000,
      'newSessionExpiry': now + 60000,
    };
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
    'public and signed sessions request only backend-scoped credentials',
    () async {
      final repository = ApiVoiceRepository(api);
      final credential = await repository.createSession(publicTestSession());
      expect(credential.token, startsWith('auth_tokens/'));
      expect(captured.url.path, '/api/v1/embed/ephemeral-token');
      expect(captured.headers.containsKey('Authorization'), isFalse);
      expect(jsonDecode(captured.body), {'receptionistId': agentId});
      await repository.createSession(testSession());
      expect(captured.headers['Authorization'], 'Bearer test-only-session');
    },
  );

  for (final change in [
    {'token': 'not-an-ephemeral-token'},
    {'token': 'auth_tokens/ bad'},
    {'newSessionExpiry': 1},
    {'expiry': 1},
    {'voiceModel': ''},
  ]) {
    test(
      'rejects unusable voice credentials: ${change.keys.first} $change',
      () async {
        payload.addAll(change);
        await expectLater(
          ApiVoiceRepository(api).createSession(publicTestSession()),
          throwsA(
            isA<AppException>().having((e) => e.kind, 'kind', ErrorKind.voice),
          ),
        );
      },
    );
  }

  test('tool calls reuse existing endpoint and embed authorization', () async {
    payload = {
      'result': {'success': true},
    };
    final result = await ApiVoiceRepository(api).executeTool(
      testSession(),
      const VoiceToolCall('call-id', 'check_appointments', {
        'date': '2026-10-16',
      }),
    );
    expect(result['success'], isTrue);
    expect(captured.url.path, '/api/v1/embed/appointment-action');
    expect(captured.headers['Authorization'], 'Bearer test-only-session');
    expect(jsonDecode(captured.body), {
      'receptionistId': agentId,
      'toolName': 'check_appointments',
      'toolArgs': {'date': '2026-10-16'},
    });
  });

  for (final message in [
    'Sorry, I am having trouble connecting right now. Please try again later.',
    'I am unable to process your request right now. Please try again later.',
    'I was unable to complete that request. Please try again.',
  ]) {
    test(
      'HTTP-200 legacy error is a failure, not an assistant reply: $message',
      () async {
        payload = {'text': message};
        await expectLater(
          ApiChatRepository(
            api,
          ).send(session: publicTestSession(), transcript: [], text: 'Hello'),
          throwsA(
            isA<AppException>().having(
              (e) => e.kind,
              'kind',
              ErrorKind.assistantUnavailable,
            ),
          ),
        );
      },
    );
  }
}
