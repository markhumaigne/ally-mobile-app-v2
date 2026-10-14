import 'package:flutter/foundation.dart';
import '../errors/app_exception.dart';

class AppConfig {
  const AppConfig({
    this.apiBaseUrl = const String.fromEnvironment('ALLY_API_BASE_URL'),
    this.requestTimeout = const Duration(seconds: 30),
    this.allowInsecureHttp = kDebugMode,
  });

  final String apiBaseUrl;
  final Duration requestTimeout;
  final bool allowInsecureHttp;

  Uri get baseUri {
    final uri = Uri.tryParse(apiBaseUrl.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (!allowInsecureHttp && uri.scheme != 'https')) {
      throw const AppException(
        ErrorKind.configuration,
        'Set ALLY_API_BASE_URL to your ALLY API URL, including /api/v1. HTTPS is required outside debug builds.',
      );
    }
    return uri.replace(path: '${uri.path.replaceFirst(RegExp(r'/+$'), '')}/');
  }

  AppException? get configurationError {
    try {
      baseUri;
      return null;
    } on AppException catch (error) {
      return error;
    }
  }
}
