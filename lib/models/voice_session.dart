import 'dart:typed_data';
import '../core/errors/app_exception.dart';

/// Short-lived credential issued by the existing ALLY backend. Memory only.
class VoiceSession {
  const VoiceSession({
    required this.token,
    required this.model,
    required this.expiresAt,
    required this.connectBy,
    this.empathy = false,
  });
  final String token;
  final String model;
  final DateTime expiresAt;
  final DateTime connectBy;
  final bool empathy;
}

enum VoiceEventKind {
  inputText,
  outputText,
  audio,
  turnComplete,
  interrupted,
  toolCall,
  toolCancelled,
  closed,
  failed,
}

class VoiceEvent {
  const VoiceEvent(this.kind, {this.text, this.audio, this.call, this.error});
  final VoiceEventKind kind;
  final String? text;
  final Uint8List? audio;
  final VoiceToolCall? call;
  final AppException? error;
}

class VoiceToolCall {
  const VoiceToolCall(this.id, this.name, this.args);
  final String id;
  final String name;
  final Map<String, dynamic> args;
}
