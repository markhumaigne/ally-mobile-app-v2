import '../core/constants/api_endpoints.dart';
import '../core/errors/app_exception.dart';
import '../models/agent_model.dart';
import '../models/chat_message_model.dart';
import '../services/api_service.dart';

abstract interface class ChatRepository {
  Future<String> send({
    required AgentSession session,
    required List<ChatMessageModel> transcript,
    required String text,
  });
}

class ApiChatRepository implements ChatRepository {
  ApiChatRepository(this._api);
  final ApiService _api;

  @override
  Future<String> send({
    required AgentSession session,
    required List<ChatMessageModel> transcript,
    required String text,
  }) async {
    if (!session.isValidAt(DateTime.now())) {
      throw AppException.fromStatus(401);
    }
    final result = jsonObject(
      await _api.post(
        ApiEndpoints.textMessage,
        token: session.embedToken,
        body: {
          'receptionistId': session.agent.id,
          'transcript': transcript
              .map((message) => message.toTranscript())
              .toList(),
          'userMessage': text,
        },
      ),
    );
    final reply = result['text'];
    if (reply is! String || reply.trim().isEmpty) throw AppException.unexpected;
    return reply.trim();
  }
}
