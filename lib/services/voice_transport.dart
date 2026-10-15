import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../core/errors/app_exception.dart';
import '../models/chat_message_model.dart';
import '../models/voice_session.dart';

abstract interface class VoiceTransport {
  Stream<VoiceEvent> get events;
  Future<void> connect(VoiceSession credential, List<ChatMessageModel> history);
  void sendAudio(Uint8List data);
  void endAudio();
  void sendText(String text);
  void sendToolResponse(VoiceToolCall call, Map<String, dynamic> result);
  Future<void> close();
}

/// Gemini's documented constrained WebSocket protocol. Only a backend-issued
/// ephemeral credential is accepted; the app never uses a Google API key.
class GeminiVoiceTransport implements VoiceTransport {
  GeminiVoiceTransport({
    this.timeout = const Duration(seconds: 25),
    Future<WebSocket> Function(Uri)? connector,
  }) : _connector = connector ?? ((uri) => WebSocket.connect(uri.toString()));
  final Future<WebSocket> Function(Uri) _connector;
  final Duration timeout;
  final _events = StreamController<VoiceEvent>();
  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Completer<void>? _setup;
  bool _closed = false;
  @override
  Stream<VoiceEvent> get events => _events.stream;

  static const unavailable = AppException(
    ErrorKind.voice,
    'The live voice connection ended. Tap voice to reconnect, or continue typing.',
  );

  @override
  Future<void> connect(
    VoiceSession credential,
    List<ChatMessageModel> history,
  ) async {
    if (_closed) return;
    if (!credential.connectBy.isAfter(DateTime.now())) throw unavailable;
    final uri = Uri(
      scheme: 'wss',
      host: 'generativelanguage.googleapis.com',
      path:
          '/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContentConstrained',
      queryParameters: {'access_token': credential.token},
    );
    try {
      // A late connection must close even if timeout/cancellation won the race.
      final pending = _connector(uri).then((socket) {
        if (_closed) {
          unawaited(socket.close());
          return socket;
        }
        _socket = socket;
        return socket;
      });
      final socket = await pending.timeout(timeout);
      if (_closed) return;
      _setup = Completer<void>();
      // Attach the timeout/error listener before handling any socket frames.
      final ready = _setup!.future.timeout(timeout);
      _subscription = socket.listen(
        _onMessage,
        onError: (Object _) => _fail(),
        onDone: () {
          if (_closed) return;
          _fail();
        },
      );
      _send({
        'setup': {
          'model': credential.model.startsWith('models/')
              ? credential.model
              : 'models/${credential.model}',
        },
      });
      await ready;
      if (_closed) return;
      final turns = history
          .where((m) => m.delivery == MessageDelivery.sent)
          .map(
            (m) => {
              'role': m.role == MessageRole.user ? 'user' : 'model',
              'parts': [
                {'text': m.text},
              ],
            },
          )
          .toList();
      if (turns.isNotEmpty) {
        _send({
          'clientContent': {'turns': turns, 'turnComplete': false},
        });
      }
    } catch (_) {
      await close();
      // Socket exceptions can contain the credential URL. Never expose them.
      throw unavailable;
    }
  }

  void _send(Map<String, dynamic> value) {
    if (_closed || _socket?.readyState != WebSocket.open) throw unavailable;
    _socket!.add(jsonEncode(value));
  }

  void _emit(VoiceEvent event) {
    if (!_closed) _events.add(event);
  }

  void _fail() {
    if (_closed) return;
    if (_setup != null && !_setup!.isCompleted) {
      _setup!.completeError(unavailable);
    }
    _emit(const VoiceEvent(VoiceEventKind.failed, error: unavailable));
  }

  void _onMessage(dynamic frame) {
    if (_closed) return;
    try {
      final msg = jsonObject(
        jsonDecode(frame is String ? frame : utf8.decode(frame as List<int>)),
      );
      if (msg.containsKey('setupComplete')) {
        if (!_setup!.isCompleted) _setup!.complete();
      }
      if (msg.containsKey('error') || msg.containsKey('goAway')) {
        _fail();
        return;
      }
      final content = msg['serverContent'];
      if (content is Map<String, dynamic>) {
        if (content['interrupted'] == true) {
          _emit(const VoiceEvent(VoiceEventKind.interrupted));
        }
        for (final entry in {
          'inputTranscription': VoiceEventKind.inputText,
          'outputTranscription': VoiceEventKind.outputText,
        }.entries) {
          final transcription = content[entry.key];
          if (transcription is Map && transcription['text'] is String) {
            _emit(
              VoiceEvent(entry.value, text: transcription['text'] as String),
            );
          }
        }
        final turn = content['modelTurn'];
        if (turn is Map && turn['parts'] is List) {
          for (final part in turn['parts'] as List) {
            if (part is! Map) continue;
            final inline = part['inlineData'];
            if (inline is Map && inline['data'] is String) {
              // ALLY's scoped model sends mono PCM16 at 24 kHz.
              final mime = inline['mimeType'];
              if (mime is! String ||
                  !mime.startsWith('audio/pcm') ||
                  (mime.contains('rate=') && !mime.contains('rate=24000'))) {
                throw AppException.unexpected;
              }
              final data = base64Decode(inline['data'] as String);
              if (data.length.isOdd) throw AppException.unexpected;
              _emit(VoiceEvent(VoiceEventKind.audio, audio: data));
            }
          }
        }
        if (content['turnComplete'] == true) {
          _emit(const VoiceEvent(VoiceEventKind.turnComplete));
        }
      }
      final calls = msg['toolCall'];
      if (calls is Map && calls['functionCalls'] is List) {
        for (final raw in calls['functionCalls'] as List) {
          final call = jsonObject(raw);
          if (call['id'] is! String || call['name'] is! String) {
            throw AppException.unexpected;
          }
          _emit(
            VoiceEvent(
              VoiceEventKind.toolCall,
              call: VoiceToolCall(
                call['id'] as String,
                call['name'] as String,
                jsonObject(call['args'] ?? <String, dynamic>{}),
              ),
            ),
          );
        }
      }
      final cancellation = msg['toolCallCancellation'];
      if (cancellation is Map && cancellation['ids'] is List) {
        for (final id in cancellation['ids'] as List) {
          if (id is String) {
            _emit(VoiceEvent(VoiceEventKind.toolCancelled, text: id));
          }
        }
      }
    } catch (_) {
      _fail();
    }
  }

  @override
  void sendAudio(Uint8List data) => _send({
    'realtimeInput': {
      'audio': {'mimeType': 'audio/pcm;rate=16000', 'data': base64Encode(data)},
    },
  });
  @override
  void endAudio() => _send({
    'realtimeInput': {'audioStreamEnd': true},
  });
  @override
  void sendText(String text) => _send({
    'clientContent': {
      'turns': [
        {
          'role': 'user',
          'parts': [
            {'text': text},
          ],
        },
      ],
      'turnComplete': true,
    },
  });
  @override
  void sendToolResponse(VoiceToolCall call, Map<String, dynamic> result) =>
      _send({
        'toolResponse': {
          'functionResponses': [
            {
              'id': call.id,
              'name': call.name,
              'response': {'output': result},
            },
          ],
        },
      });
  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (_setup != null && !_setup!.isCompleted) _setup!.complete();
    await _subscription?.cancel();
    // Don't wait indefinitely for the remote peer's close handshake.
    unawaited(
      _socket?.close().catchError((Object _) {}) ?? Future<void>.value(),
    );
    await _events.close();
  }
}
