import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/errors/app_exception.dart';
import '../models/agent_model.dart';
import '../models/chat_message_model.dart';
import '../models/voice_session.dart';
import '../models/voice_state.dart';
import '../repositories/voice_repository.dart';
import '../services/voice_audio_service.dart';
import '../services/voice_transport.dart';
import 'agent_provider.dart';
import 'chat_provider.dart';

class VoiceProvider extends ChangeNotifier {
  VoiceProvider(
    this._repository,
    this._agents,
    this._chat, {
    VoiceAudioService? audio,
    VoiceTransport Function()? transportFactory,
    this.introductionTimeout = const Duration(seconds: 45),
  }) : _audio = audio ?? AndroidVoiceAudioService(),
       _transportFactory = transportFactory ?? GeminiVoiceTransport.new {
    _session = _agents.session;
    _agents.addListener(_agentChanged);
    _playback = _audio.playback.listen((playing) {
      _playing = playing;
      _listenWhenReady();
    });
  }
  final VoiceRepository? _repository;
  final AgentProvider _agents;
  final ChatProvider _chat;
  final VoiceAudioService _audio;
  final VoiceTransport Function() _transportFactory;
  final Duration introductionTimeout;
  AgentSession? _session;
  VoiceTransport? _transport;
  StreamSubscription<VoiceEvent>? _events;
  StreamSubscription<Uint8List>? _microphone;
  late final StreamSubscription<bool> _playback;
  Timer? _expiry;
  Timer? _introductionTimer;
  Future<void> _cleanup = Future<void>.value();
  final Set<String> _handledTools = {};
  final Set<String> _cancelledTools = {};
  VoiceState _state = VoiceState.idle;
  AppException? _error;
  bool _disposed = false;
  bool _playing = false;
  bool _turnComplete = true;
  bool _sentAudio = false;
  bool _introducing = false;
  bool _introductionHasAudio = false;
  int _pendingPlayback = 0;
  int _generation = 0;

  VoiceState get state => _state;
  AppException? get error => _error;
  bool get busy => _state == VoiceState.connecting;
  bool get connected => {
    VoiceState.listening,
    VoiceState.thinking,
    VoiceState.speaking,
  }.contains(_state);
  bool get canSendText =>
      !busy && !_introducing && _state != VoiceState.thinking;
  String get statusLabel => switch (_state) {
    VoiceState.idle => 'Ready to start',
    VoiceState.thinking when _introducing => 'Preparing introduction…',
    VoiceState.speaking when _introducing => 'Introducing…',
    VoiceState.disconnected => 'Voice off · Type or tap voice',
    VoiceState.error => 'Voice unavailable · You can still type',
    _ => _state.label,
  };

  bool _current(int generation) => !_disposed && generation == _generation;
  void _setState(VoiceState value) {
    if (_state == value) return;
    _state = value;
    if (kDebugMode) debugPrint('[ALLY Voice] state=${value.name}');
    if (!_disposed) notifyListeners();
  }

  void _agentChanged() {
    if (identical(_session, _agents.session)) return;
    _session = _agents.session;
    unawaited(stop());
  }

  Future<void> start() async {
    if (_disposed || busy || connected || _chat.isSending) return;
    _agents.checkExpiry();
    final agent = _agents.session;
    if (agent == null || !_agents.hasSession) return;
    final generation = ++_generation;
    _error = null;
    _setState(VoiceState.connecting);
    try {
      await _cleanup;
      if (!_current(generation)) return;
      if (_repository == null) {
        throw const AppException(
          ErrorKind.configuration,
          'Voice is not configured in this build.',
        );
      }
      final allowed = await _audio.requestPermission();
      if (!_current(generation)) return;
      if (!allowed) {
        throw const AppException(
          ErrorKind.microphone,
          'Microphone permission is off. Allow it in Android Settings → Apps → ALLY → Permissions, or keep typing.',
        );
      }
      final credential = await _repository.createSession(agent);
      if (!_current(generation)) return;
      final transport = _transportFactory();
      _transport = transport;
      _events = transport.events.listen(
        (event) {
          if (_current(generation)) {
            unawaited(_handle(event, generation, agent));
          }
        },
        onError: (Object _) =>
            _fail(GeminiVoiceTransport.unavailable, generation),
      );
      await transport.connect(credential, _chat.messages);
      if (!_current(generation)) return;
      final input = await _audio.start(empathy: credential.empathy);
      if (!_current(generation)) return;
      _turnComplete = false;
      _playing = false;
      _introducing = true;
      _introductionHasAudio = false;
      _microphone = input.listen(
        (pcm) {
          if (!_current(generation) || !connected) return;
          // Half-duplex echo guard, matching the demo: do not send speaker audio
          // back to the model. The stop button remains available during speech.
          if (_introducing || _playing || _state == VoiceState.speaking) {
            if (_sentAudio) {
              _sentAudio = false;
              _trySend(transport.endAudio, generation);
            }
            return;
          }
          _sentAudio = true;
          _trySend(() => transport.sendAudio(pcm), generation);
        },
        onError: (Object _) => _fail(
          const AppException(
            ErrorKind.microphone,
            'The microphone stopped. Tap voice to reconnect.',
          ),
          generation,
        ),
        onDone: () {
          if (_current(generation)) {
            _fail(
              const AppException(
                ErrorKind.microphone,
                'Microphone recording ended. Tap voice to reconnect.',
              ),
              generation,
            );
          }
        },
      );
      _expiry = Timer(
        credential.expiresAt.difference(DateTime.now()),
        () => _fail(
          const AppException(
            ErrorKind.voice,
            'This voice session has expired. Tap voice to start a new one.',
          ),
          generation,
        ),
      );
      // Like the web embed's greeting turn, this requests a real spoken reply
      // after setup/history sync. It is a control cue, not a user chat bubble.
      // Backend-scoped identity and voice settings still govern the response.
      _introductionTimer = Timer(
        introductionTimeout,
        () => _fail(
          const AppException(
            ErrorKind.voice,
            'The introduction did not finish. Tap voice to try again, or keep typing.',
          ),
          generation,
        ),
      );
      _setState(VoiceState.thinking);
      transport.sendText(
        _chat.messages.any((m) => m.delivery == MessageDelivery.sent)
            ? 'Voice has just started in this existing conversation. Briefly '
                  'welcome the user back in your configured persona, then invite '
                  'them to speak. Do not repeat earlier answers or perform any '
                  'actions. Do not use tools. Wait for the user after greeting.'
            : 'Voice has just started. Greet the user and briefly introduce '
                  'yourself using your configured name and role, then ask how '
                  'you can help. Keep the spoken introduction short. Do not use '
                  'tools. Wait for the user after your introduction.',
      );
    } catch (error) {
      if (_current(generation)) {
        await _fail(
          error is AppException
              ? error
              : const AppException(
                  ErrorKind.voice,
                  'Unable to start voice. Check microphone access and your connection, then try again.',
                ),
          generation,
        );
      }
    }
  }

  void _listenWhenReady() {
    if (!connected || !_turnComplete || _playing || _pendingPlayback > 0) {
      return;
    }
    if (_introducing) {
      if (!_introductionHasAudio) {
        unawaited(
          _fail(
            const AppException(
              ErrorKind.voice,
              'The assistant could not speak its introduction. Tap voice to try again, or keep typing.',
            ),
            _generation,
          ),
        );
        return;
      }
      _introducing = false;
      _introductionTimer?.cancel();
    }
    _setState(VoiceState.listening);
  }

  void _trySend(void Function() action, int generation) {
    try {
      action();
    } catch (_) {
      unawaited(_fail(GeminiVoiceTransport.unavailable, generation));
    }
  }

  Future<void> _handle(
    VoiceEvent event,
    int generation,
    AgentSession agent,
  ) async {
    try {
      switch (event.kind) {
        case VoiceEventKind.inputText:
          if (_introducing) return;
          _turnComplete = false;
          _chat.addVoiceText(MessageRole.user, event.text!);
          if (!_playing) _setState(VoiceState.thinking);
        case VoiceEventKind.outputText:
          _chat.addVoiceText(MessageRole.assistant, event.text!);
        case VoiceEventKind.audio:
          if (event.audio!.isEmpty) return;
          _turnComplete = false;
          _playing = true;
          if (_introducing) _introductionHasAudio = true;
          ++_pendingPlayback;
          _setState(VoiceState.speaking);
          try {
            await _audio.play(event.audio!);
          } finally {
            if (_current(generation)) --_pendingPlayback;
          }
          if (_current(generation)) _listenWhenReady();
        case VoiceEventKind.turnComplete:
          _turnComplete = true;
          _chat.finishVoiceTurn();
          _listenWhenReady();
        case VoiceEventKind.interrupted:
          if (_introducing) {
            throw const AppException(
              ErrorKind.voice,
              'The introduction was interrupted. Tap voice to try again, or keep typing.',
            );
          }
          await _audio.interrupt();
          if (!_current(generation)) return;
          _playing = false;
          _turnComplete = true;
          _chat.finishVoiceTurn();
          _setState(VoiceState.listening);
        case VoiceEventKind.toolCall:
          final call = event.call!;
          if (!_handledTools.add(call.id) ||
              _cancelledTools.contains(call.id)) {
            return;
          }
          if (_introducing) {
            _transport!.sendToolResponse(call, {
              'success': false,
              'message':
                  'This opening turn is only a greeting. Introduce yourself without tools and wait for the user.',
            });
            return;
          }
          _setState(VoiceState.thinking);
          Map<String, dynamic> output;
          try {
            output = await _repository!.executeTool(agent, call);
          } on AppException catch (error) {
            if (error.invalidatesSession) rethrow;
            output = {
              'success': false,
              'message':
                  'Appointment service unavailable; action may be unconfirmed. Do not retry automatically.',
            };
          }
          if (_current(generation) && !_cancelledTools.contains(call.id)) {
            _transport!.sendToolResponse(call, output);
          }
        case VoiceEventKind.toolCancelled:
          _cancelledTools.add(event.text!);
        case VoiceEventKind.closed:
        case VoiceEventKind.failed:
          await _fail(
            event.error ?? GeminiVoiceTransport.unavailable,
            generation,
          );
      }
    } catch (error) {
      if (_current(generation)) {
        await _fail(
          error is AppException ? error : GeminiVoiceTransport.unavailable,
          generation,
        );
      }
    }
  }

  void sendText(String text) {
    if (!connected || !canSendText || text.trim().isEmpty) return;
    final generation = _generation;
    _trySend(() {
      _transport!.sendText(text.trim());
      _chat.finishVoiceTurn();
      _chat.addVoiceText(MessageRole.user, text.trim(), complete: true);
      _turnComplete = false;
      _setState(VoiceState.thinking);
    }, generation);
  }

  Future<void> _fail(AppException error, int generation) async {
    if (!_current(generation)) return;
    await stop();
    if (_disposed || generation + 1 != _generation) return;
    _error = error;
    _setState(VoiceState.error);
    if (error.invalidatesSession) _agents.invalidate(error);
  }

  Future<void> stop() {
    ++_generation;
    _expiry?.cancel();
    _introductionTimer?.cancel();
    final microphone = _microphone;
    final events = _events;
    final transport = _transport;
    _microphone = null;
    _events = null;
    _transport = null;
    _handledTools.clear();
    _cancelledTools.clear();
    _sentAudio = false;
    _introducing = false;
    _introductionHasAudio = false;
    _pendingPlayback = 0;
    _turnComplete = true;
    _playing = false;
    _error = null;
    _chat.finishVoiceTurn();
    _setState(VoiceState.disconnected);
    // Release audio immediately, independently of stream/socket cleanup. A
    // stalled close handshake must never keep the microphone recording.
    _cleanup =
        Future.wait<void>([
          _cleanup,
          _audio.stop(),
          if (microphone != null) microphone.cancel(),
          if (events != null) events.cancel(),
          if (transport != null) transport.close(),
        ]).then<void>((_) {}).catchError((Object _) {
          // Cleanup errors must never keep the app on the voice screen.
        });
    return _cleanup;
  }

  @override
  void dispose() {
    _disposed = true;
    _agents.removeListener(_agentChanged);
    unawaited(_playback.cancel());
    unawaited(stop().then((_) => _audio.dispose()));
    super.dispose();
  }
}
