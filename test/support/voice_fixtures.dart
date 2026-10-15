import 'dart:async';
import 'dart:typed_data';
import 'package:ally_mobile_app/models/agent_model.dart';
import 'package:ally_mobile_app/models/chat_message_model.dart';
import 'package:ally_mobile_app/models/voice_session.dart';
import 'package:ally_mobile_app/repositories/voice_repository.dart';
import 'package:ally_mobile_app/services/voice_audio_service.dart';
import 'package:ally_mobile_app/services/voice_transport.dart';

VoiceSession voiceCredential() => VoiceSession(
  token: 'auth_tokens/test-only',
  model: 'test-model',
  expiresAt: DateTime.now().add(const Duration(minutes: 30)),
  connectBy: DateTime.now().add(const Duration(seconds: 60)),
);

class FakeVoiceRepository implements VoiceRepository {
  int calls = 0;
  int toolCalls = 0;
  Completer<VoiceSession>? pending;
  Completer<Map<String, dynamic>>? pendingTool;
  Object? failure;
  @override
  Future<VoiceSession> createSession(AgentSession agent) async {
    calls++;
    if (failure != null) throw failure!;
    return pending == null ? voiceCredential() : pending!.future;
  }

  @override
  Future<Map<String, dynamic>> executeTool(
    AgentSession agent,
    VoiceToolCall call,
  ) async {
    toolCalls++;
    return pendingTool == null ? {'success': true} : pendingTool!.future;
  }
}

class FakeVoiceAudio implements VoiceAudioService {
  bool allowed = true;
  bool stopped = false;
  int starts = 0;
  int interrupts = 0;
  int samples = 0;
  Completer<bool>? permission;
  Completer<void>? pendingPlay;
  final input = StreamController<Uint8List>.broadcast();
  final playing = StreamController<bool>.broadcast();
  @override
  Stream<bool> get playback => playing.stream;
  @override
  Future<bool> requestPermission() async =>
      permission == null ? allowed : permission!.future;
  @override
  Future<Stream<Uint8List>> start({required bool empathy}) async {
    starts++;
    stopped = false;
    return input.stream;
  }

  @override
  Future<void> play(Uint8List pcm) async {
    samples += pcm.length ~/ 2;
    playing.add(true);
    await pendingPlay?.future;
  }

  @override
  Future<void> interrupt() async {
    interrupts++;
    playing.add(false);
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }

  @override
  Future<void> dispose() async {
    await input.close();
    await playing.close();
  }
}

class FakeVoiceTransport implements VoiceTransport {
  final controller = StreamController<VoiceEvent>.broadcast();
  bool closed = false;
  int audioChunks = 0;
  int toolResponses = 0;
  final texts = <String>[];
  List<ChatMessageModel> history = [];
  Completer<void>? pending;
  @override
  Stream<VoiceEvent> get events => controller.stream;
  @override
  Future<void> connect(
    VoiceSession credential,
    List<ChatMessageModel> history,
  ) async {
    this.history = history;
    await pending?.future;
  }

  @override
  void sendAudio(Uint8List data) {
    audioChunks++;
  }

  @override
  void endAudio() {}
  @override
  void sendText(String text) {
    texts.add(text);
  }

  @override
  void sendToolResponse(VoiceToolCall call, Map<String, dynamic> result) {
    toolResponses++;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}
