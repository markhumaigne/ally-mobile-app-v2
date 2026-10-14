/// Relative to ALLY_API_BASE_URL (normally https://host/api/v1).
abstract final class ApiEndpoints {
  static String agentConfig(String id) =>
      'embed/config/${Uri.encodeComponent(id)}';
  static const textMessage = 'embed/text-message';

  /// Only log known route templates. Never log IDs, hosts, query data or tokens.
  static String logLabel(String path) {
    if (RegExp(r'^embed/config/[^/]+$').hasMatch(path)) {
      return 'embed/config/:agentId';
    }
    return path == textMessage ? textMessage : '[redacted-route]';
  }
}
