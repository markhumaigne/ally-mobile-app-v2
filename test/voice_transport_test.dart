import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ally_mobile_app/core/errors/app_exception.dart';
import 'package:ally_mobile_app/models/chat_message_model.dart';
import 'package:ally_mobile_app/models/voice_session.dart';
import 'package:ally_mobile_app/services/voice_transport.dart';
import 'support/voice_fixtures.dart';

class TestSocket extends Fake implements WebSocket {
  final input = StreamController<dynamic>();
  final sent = <Map<String, dynamic>>[];
  bool closed = false;
  @override
  int get readyState => closed ? WebSocket.closed : WebSocket.open;
  @override
  void add(dynamic data) {
    final message = jsonDecode(data as String) as Map<String, dynamic>;
    sent.add(message);
    if (message.containsKey('setup')) input.add('{"setupComplete":{}}');
  }

  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => input.stream.listen(onData, onError: onError, onDone: onDone);
  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
  }
}

void main() {
  test(
    'constrained setup, history, PCM and live transcripts use real wire format',
    () async {
      final socket = TestSocket();
      Uri? endpoint;
      final transport = GeminiVoiceTransport(
        connector: (uri) async {
          endpoint = uri;
          return socket;
        },
      );
      final events = <VoiceEvent>[];
      final subscription = transport.events.listen(events.add);
      await transport.connect(voiceCredential(), const [
        ChatMessageModel(id: 1, role: MessageRole.user, text: 'Hello'),
        ChatMessageModel(id: 2, role: MessageRole.assistant, text: 'Hi'),
        ChatMessageModel(
          id: 3,
          role: MessageRole.user,
          text: 'failed',
          delivery: MessageDelivery.failed,
        ),
      ]);
      expect(endpoint!.host, 'generativelanguage.googleapis.com');
      expect(
        endpoint!.queryParameters['access_token'],
        'auth_tokens/test-only',
      );
      expect(socket.sent[0], {
        'setup': {'model': 'models/test-model'},
      });
      expect((socket.sent[1]['clientContent']['turns'] as List), hasLength(2));
      transport.sendAudio(Uint8List.fromList([0, 1]));
      expect(socket.sent.last['realtimeInput']['audio'], {
        'mimeType': 'audio/pcm;rate=16000',
        'data': 'AAE=',
      });
      transport.sendText('Question');
      expect(socket.sent.last['clientContent']['turnComplete'], isTrue);
      socket.input.add(
        jsonEncode({
          'serverContent': {
            'inputTranscription': {'text': 'Hello'},
            'outputTranscription': {'text': 'Hi'},
            'modelTurn': {
              'parts': [
                {
                  'inlineData': {
                    'mimeType': 'audio/pcm;rate=24000',
                    'data': 'AAE=',
                  },
                },
              ],
            },
            'turnComplete': true,
          },
        }),
      );
      await Future<void>.delayed(Duration.zero);
      expect(events.map((e) => e.kind), [
        VoiceEventKind.inputText,
        VoiceEventKind.outputText,
        VoiceEventKind.audio,
        VoiceEventKind.turnComplete,
      ]);
      await subscription.cancel();
      await transport.close();
      expect(socket.closed, isTrue);
    },
  );

  test(
    'a late socket after timeout is closed; credentials never enter error message',
    () async {
      final pending = Completer<WebSocket>();
      final socket = TestSocket();
      final transport = GeminiVoiceTransport(
        timeout: const Duration(milliseconds: 5),
        connector: (_) => pending.future,
      );
      final subscription = transport.events.listen((_) {});
      await expectLater(
        transport.connect(voiceCredential(), []),
        throwsA(
          isA<AppException>().having(
            (e) => e.message.contains('auth_tokens'),
            'leaks token',
            isFalse,
          ),
        ),
      );
      pending.complete(socket);
      await Future<void>.delayed(Duration.zero);
      expect(socket.closed, isTrue);
      await subscription.cancel();
    },
  );
}
