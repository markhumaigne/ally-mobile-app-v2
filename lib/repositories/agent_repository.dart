import '../core/constants/api_endpoints.dart';
import '../core/errors/app_exception.dart';
import '../core/validation/uuid_validator.dart';
import '../models/agent_model.dart';
import '../services/api_service.dart';

abstract interface class AgentRepository {
  Future<AgentSession> activate(String agentId, {String? userReference});
}

class ApiAgentRepository implements AgentRepository {
  ApiAgentRepository(this._api, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final ApiService _api;
  final DateTime Function() _now;

  @override
  Future<AgentSession> activate(String agentId, {String? userReference}) async {
    final id = agentId.trim().toLowerCase();
    if (!UuidValidator.isValid(id)) {
      throw const AppException(
        ErrorKind.invalidRequest,
        'Enter a valid Agent UUID.',
      );
    }
    // The inspected embed endpoint accepts no userId. Never send it as auth.
    final result = jsonObject(await _api.get(ApiEndpoints.agentConfig(id)));
    if (result['status'] != 'success') throw AppException.unexpected;
    final data = jsonObject(result['data']);
    if (data['id'] is! String ||
        (data['id'] as String).toLowerCase() != id ||
        data['status'] is! String) {
      throw AppException.unexpected;
    }
    if (data['status'] != 'active') {
      throw const AppException(
        ErrorKind.inactiveAgent,
        'This agent is inactive or unavailable. Contact the agent owner.',
      );
    }
    if (data['subscriptions'] == null) {
      throw const AppException(
        ErrorKind.subscriptionUnverified,
        'No linked subscription was returned. An active subscription must be verified before activation.',
      );
    }
    final subscription = jsonObject(data['subscriptions']);
    if (subscription['status'] is! String) throw AppException.unexpected;
    if (subscription['status'] != 'active') {
      throw const AppException(
        ErrorKind.inactiveSubscription,
        'This agent’s subscription is not active. Contact the agent owner.',
      );
    }
    final token = result['embedToken'];
    final expiry = result['embedTokenExpiresAt'];
    if (token is! String ||
        token.isEmpty ||
        token.length > 2048 ||
        RegExp(r'\s').hasMatch(token) ||
        expiry is! int ||
        expiry <=
            _now().add(const Duration(seconds: 30)).millisecondsSinceEpoch ||
        expiry > _now().add(const Duration(hours: 1)).millisecondsSinceEpoch) {
      throw const AppException(
        ErrorKind.unauthorized,
        'The backend did not issue a usable assistant session. Check embed-session configuration.',
      );
    }
    final name = data['name'];
    if (name != null && name is! String) throw AppException.unexpected;
    return AgentSession(
      agent: AgentModel(
        id: id,
        name: name is String && name.trim().isNotEmpty
            ? name.trim()
            : 'ALLY Assistant',
        subscriptionStatus: subscription['status'] as String,
      ),
      embedToken: token,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiry),
      userReference: userReference?.trim().isEmpty ?? true
          ? null
          : userReference!.trim(),
    );
  }
}
