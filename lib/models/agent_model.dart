class AgentModel {
  const AgentModel({
    required this.id,
    required this.name,
    required this.subscriptionStatus,
  });
  final String id;
  final String name;
  final String subscriptionStatus;
}

/// Public embed permission, not an authenticated account or ownership claim.
/// Credentials and optional user reference stay in memory only.
class AgentSession {
  const AgentSession({
    required this.agent,
    required this.embedToken,
    required this.expiresAt,
    this.userReference,
  });
  final AgentModel agent;
  final String embedToken;
  final DateTime expiresAt;
  final String? userReference;

  bool isValidAt(DateTime now) => expiresAt.isAfter(now);
}
