import 'package:ally_mobile_app/models/agent_model.dart';
import 'package:ally_mobile_app/models/chat_message_model.dart';
import 'package:ally_mobile_app/repositories/agent_repository.dart';
import 'package:ally_mobile_app/repositories/chat_repository.dart';

// Synthetic test-only identifiers and credentials; never used by lib/.
const agentId = '11111111-1111-4111-8111-111111111111';
const otherAgentId = '22222222-2222-4222-8222-222222222222';

Map<String, dynamic> activationPayload({DateTime? now}) => {
  'status': 'success',
  'data': <String, dynamic>{
    'id': agentId,
    'name': 'Test Concierge',
    'status': 'active',
    'subscriptions': {'id': 'test-subscription', 'status': 'active'},
  },
  'embedToken': 'test-only-session',
  'embedTokenExpiresAt': (now ?? DateTime.now())
      .add(const Duration(minutes: 30))
      .millisecondsSinceEpoch,
};

AgentSession testSession({String id = agentId, DateTime? expiresAt}) =>
    AgentSession(
      agent: AgentModel(
        id: id,
        name: 'Test Concierge',
        subscriptionStatus: 'active',
      ),
      embedToken: 'test-only-session',
      expiresAt: expiresAt ?? DateTime.now().add(const Duration(minutes: 30)),
    );

AgentSession publicTestSession({String id = agentId}) => AgentSession(
  agent: AgentModel(id: id, name: 'Test Concierge'),
);

class FakeAgentRepository implements AgentRepository {
  int calls = 0;
  String? userReference;
  Future<AgentSession> Function(String)? handler;
  @override
  Future<AgentSession> activate(String id, {String? userReference}) async {
    calls++;
    this.userReference = userReference;
    return handler == null ? testSession(id: id) : handler!(id);
  }
}

class FakeChatRepository implements ChatRepository {
  int calls = 0;
  AgentSession? receivedSession;
  List<ChatMessageModel>? receivedTranscript;
  Future<String> Function()? handler;
  @override
  Future<String> send({
    required AgentSession session,
    required List<ChatMessageModel> transcript,
    required String text,
  }) async {
    calls++;
    receivedSession = session;
    receivedTranscript = transcript;
    return handler == null ? 'Test response' : handler!();
  }
}
