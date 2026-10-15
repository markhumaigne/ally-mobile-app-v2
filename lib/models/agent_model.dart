class AgentModel {
  const AgentModel({
    required this.id,
    required this.name,
    this.subscriptionStatus,
  });
  final String id;
  final String name;
  final String? subscriptionStatus;
}

/// A backend-validated active agent, not an account or ownership claim.
/// Older public embed deployments omit credentials and expiry. Newer deployments
/// return both; the backend remains responsible for authorizing chat requests.
class AgentSession {
  const AgentSession({
    required this.agent,
    this.embedToken,
    this.expiresAt,
    this.userReference,
  });
  final AgentModel agent;
  final String? embedToken;
  final DateTime? expiresAt;
  final String? userReference;

  bool isValidAt(DateTime now) =>
      embedToken == null ? expiresAt == null : expiresAt?.isAfter(now) ?? false;
}
