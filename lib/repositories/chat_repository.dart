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
        // Public deployments omit credentials; signed deployments receive the
        // token unchanged. A rejection is never retried without credentials.
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
    // Exact legacy fallback strings from EmbedService.sendTextMessage. These
    // are HTTP-200 failures, not assistant turns; never put them in history.
    if ({
      'Sorry, I am having trouble connecting right now. Please try again later.',
      'I am unable to process your request right now. Please try again later.',
      'I was unable to complete that request. Please try again.',
    }.contains(reply.trim())) {
      throw const AppException(
        ErrorKind.assistantUnavailable,
        'Your assistant is temporarily unavailable. Your message is still here. '
        'Please try again shortly.',
        statusCode: 200,
      );
    }
    return reply.trim();
  }
}
