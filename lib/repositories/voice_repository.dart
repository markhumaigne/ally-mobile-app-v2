import '../core/constants/api_endpoints.dart';
import '../core/errors/app_exception.dart';
import '../models/agent_model.dart';
import '../models/voice_session.dart';
import '../services/api_service.dart';

abstract interface class VoiceRepository {
  Future<VoiceSession> createSession(AgentSession agent);
  Future<Map<String, dynamic>> executeTool(
    AgentSession agent,
    VoiceToolCall call,
  );
}

class ApiVoiceRepository implements VoiceRepository {
  ApiVoiceRepository(this._api);
  final ApiService _api;

  @override
  Future<VoiceSession> createSession(AgentSession agent) async {
    if (!agent.isValidAt(DateTime.now())) throw AppException.fromStatus(401);
    final data = jsonObject(
      await _api.post(
        ApiEndpoints.voiceToken,
        token: agent.embedToken,
        body: {'receptionistId': agent.agent.id},
      ),
    );
    final token = data['token'];
    final model = data['voiceModel'];
    final expiry = data['expiry'];
    final connectBy = data['newSessionExpiry'];
    final now = DateTime.now().millisecondsSinceEpoch;
    if (token is! String ||
        !token.startsWith('auth_tokens/') ||
        token.length > 4096 ||
        RegExp(r'\s').hasMatch(token) ||
        model is! String ||
        !RegExp(r'^(models/)?[a-zA-Z0-9._-]+$').hasMatch(model) ||
        expiry is! int ||
        connectBy is! int ||
        expiry <= now + 5000 ||
        connectBy <= now + 5000 ||
        expiry > now + const Duration(hours: 1).inMilliseconds ||
        connectBy > expiry) {
      throw const AppException(
        ErrorKind.voice,
        'The backend returned an invalid or expired voice credential. Tap voice to try again.',
      );
    }
    return VoiceSession(
      token: token,
      model: model,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiry),
      connectBy: DateTime.fromMillisecondsSinceEpoch(connectBy),
      empathy: data['voiceEmpathy'] == true,
    );
  }

  @override
  Future<Map<String, dynamic>> executeTool(
    AgentSession agent,
    VoiceToolCall call,
  ) async {
    if (!agent.isValidAt(DateTime.now())) throw AppException.fromStatus(401);
    // The existing backend validates tool names and arguments and owns all
    // calendar actions. Never run a URL, code or function supplied by the model.
    final result = jsonObject(
      await _api.post(
        ApiEndpoints.appointmentAction,
        token: agent.embedToken,
        body: {
          'receptionistId': agent.agent.id,
          'toolName': call.name,
          'toolArgs': call.args,
        },
      ),
    );
    final output = jsonObject(result['result']);
    if (output.isEmpty) throw AppException.unexpected;
    return output;
  }
}
