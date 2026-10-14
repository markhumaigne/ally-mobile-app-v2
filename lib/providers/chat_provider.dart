import 'package:flutter/foundation.dart';
import '../core/errors/app_exception.dart';
import '../models/agent_model.dart';
import '../models/chat_message_model.dart';
import '../repositories/chat_repository.dart';
import 'agent_provider.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider(this._repository, this._agents) {
    _session = _agents.session;
    _agents.addListener(_onAgentChanged);
  }
  final ChatRepository _repository;
  final AgentProvider _agents;
  AgentSession? _session;
  final List<ChatMessageModel> _messages = [];
  AppException? _error;
  bool _sending = false;
  bool _disposed = false;
  int _generation = 0;
  int _messageId = 0;

  List<ChatMessageModel> get messages => List.unmodifiable(_messages);
  AppException? get error => _error;
  bool get isSending => _sending;

  void _onAgentChanged() {
    if (identical(_session, _agents.session)) return;
    _session = _agents.session;
    reset();
  }

  Future<void> send(String value) async {
    final text = value.trim();
    if (text.isEmpty || _sending || _disposed) return;
    _agents.checkExpiry();
    final session = _agents.session;
    if (session == null || !_agents.hasSession) return;
    final generation = _generation;
    final message = ChatMessageModel(
      id: ++_messageId,
      role: MessageRole.user,
      text: text,
      delivery: MessageDelivery.pending,
    );
    _messages.add(message);
    _sending = true;
    _error = null;
    notifyListeners();
    try {
      // Matches Angular: snapshot includes the current user message. Failed
      // requests are excluded because receipt by the server is uncertain.
      final reply = await _repository.send(
        session: session,
        transcript: _messages
            .where((m) => m.delivery != MessageDelivery.failed)
            .toList(),
        text: text,
      );
      if (_disposed || generation != _generation) return;
      _replace(message.withDelivery(MessageDelivery.sent));
      _messages.add(
        ChatMessageModel(
          id: ++_messageId,
          role: MessageRole.assistant,
          text: reply,
        ),
      );
    } catch (error) {
      if (_disposed || generation != _generation) return;
      _error = error is AppException ? error : AppException.unknown;
      _replace(message.withDelivery(MessageDelivery.failed));
      if (_error!.invalidatesSession) {
        _agents.invalidate(_error!);
        return;
      }
    } finally {
      if (!_disposed && generation == _generation) {
        _sending = false;
        notifyListeners();
      }
    }
  }

  void _replace(ChatMessageModel message) {
    final index = _messages.indexWhere((item) => item.id == message.id);
    if (index >= 0) _messages[index] = message;
  }

  void reset() {
    ++_generation;
    _messages.clear();
    _sending = false;
    _error = null;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _agents.removeListener(_onAgentChanged);
    super.dispose();
  }
}
