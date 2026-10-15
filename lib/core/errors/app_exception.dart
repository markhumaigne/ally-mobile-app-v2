enum ErrorKind {
  configuration,
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  invalidRequest,
  inactiveAgent,
  inactiveSubscription,
  rateLimited,
  server,
  assistantUnavailable,
  microphone,
  voice,
  unexpectedResponse,
  unknown,
}

class AppException implements Exception {
  const AppException(this.kind, this.message, {this.statusCode});

  final ErrorKind kind;
  final String message;
  final int? statusCode;

  bool get invalidatesSession => {
    ErrorKind.unauthorized,
    ErrorKind.forbidden,
    ErrorKind.notFound,
    ErrorKind.inactiveAgent,
    ErrorKind.inactiveSubscription,
  }.contains(kind);

  factory AppException.fromStatus(int status) {
    final (kind, message) = switch (status) {
      400 || 422 => (
        ErrorKind.invalidRequest,
        'The server rejected this request. Check the Agent UUID.',
      ),
      401 => (
        ErrorKind.unauthorized,
        'Your assistant session has expired or is unauthorized. Activate the agent again.',
      ),
      402 => (
        ErrorKind.inactiveSubscription,
        'This agent does not have an active subscription.',
      ),
      403 => (ErrorKind.forbidden, 'Access to this agent was denied.'),
      404 => (
        ErrorKind.notFound,
        'Agent or API route not found. Check the Agent UUID and API configuration.',
      ),
      408 || 504 => (
        ErrorKind.timeout,
        'The server took too long to respond. Try again shortly.',
      ),
      429 => (
        ErrorKind.rateLimited,
        'Too many requests. Wait a moment before trying again.',
      ),
      >= 500 => (
        ErrorKind.server,
        'The ALLY service is temporarily unavailable. Try again later.',
      ),
      _ => (
        ErrorKind.invalidRequest,
        'The server could not complete this request.',
      ),
    };
    return AppException(kind, message, statusCode: status);
  }

  static const unexpected = AppException(
    ErrorKind.unexpectedResponse,
    'The server returned an unexpected response. Check that the API matches the supported ALLY contract.',
  );
  static const unknown = AppException(
    ErrorKind.unknown,
    'Something went wrong. Please try again.',
  );

  // Deliberately excludes response bodies, request data, and credentials.
  @override
  String toString() => 'AppException(${kind.name}, status: $statusCode)';
}

Map<String, dynamic> jsonObject(Object? value) {
  if (value is! Map<String, dynamic>) throw AppException.unexpected;
  return value;
}
