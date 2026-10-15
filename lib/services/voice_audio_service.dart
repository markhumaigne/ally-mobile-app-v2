import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:record/record.dart';

abstract interface class VoiceAudioService {
  Future<bool> requestPermission();
  Future<Stream<Uint8List>> start({required bool empathy});
  Future<void> play(Uint8List pcm);
  Future<void> interrupt();
  Future<void> stop();
  Future<void> dispose();
  Stream<bool> get playback;
}

/// Only audio capture/playback lives here. PCM never touches the filesystem.
class AndroidVoiceAudioService implements VoiceAudioService {
  AudioRecorder? _recorder;
  final _playback = StreamController<bool>.broadcast();
  Future<void> _operations = Future<void>.value();
  bool _started = false;
  bool _disposed = false;
  @override
  Stream<bool> get playback => _playback.stream;

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _operations.then((_) => operation());
    _operations = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  @override
  Future<bool> requestPermission() =>
      (_recorder ??= AudioRecorder()).hasPermission();

  Future<void> _setupSpeaker() async {
    await FlutterPcmSound.setLogLevel(LogLevel.none);
    await FlutterPcmSound.setup(sampleRate: 24000, channelCount: 1);
    await FlutterPcmSound.setFeedThreshold(0);
    FlutterPcmSound.setFeedCallback((remaining) {
      if (!_disposed && _started && remaining == 0) _playback.add(false);
    });
  }

  @override
  Future<Stream<Uint8List>> start({required bool empathy}) =>
      _serialize(() async {
        _started = true;
        await _setupSpeaker();
        return (_recorder ??= AudioRecorder()).startStream(
          RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1,
            echoCancel: true,
            noiseSuppress: !empathy,
            autoGain: !empathy,
            streamBufferSize: 3200,
            androidConfig: const AndroidRecordConfig(
              manageBluetooth: false,
              audioSource: AndroidAudioSource.voiceCommunication,
            ),
          ),
        );
      });

  @override
  Future<void> play(Uint8List pcm) => _serialize(() async {
    if (!_started || _disposed || pcm.isEmpty) return;
    _playback.add(true);
    await FlutterPcmSound.feed(PcmArrayInt16(bytes: ByteData.sublistView(pcm)));
  });

  @override
  Future<void> interrupt() => _serialize(() async {
    if (!_started) return;
    await FlutterPcmSound.release();
    await _setupSpeaker();
    if (!_disposed) _playback.add(false);
  });

  @override
  Future<void> stop() => _serialize(() async {
    if (!_started) return;
    _started = false;
    try {
      await _recorder?.stop();
    } finally {
      FlutterPcmSound.setFeedCallback(null);
      await FlutterPcmSound.release();
      if (!_disposed) _playback.add(false);
    }
  });

  @override
  Future<void> dispose() async {
    _disposed = true;
    await stop();
    await _recorder?.dispose();
    await _playback.close();
  }
}
