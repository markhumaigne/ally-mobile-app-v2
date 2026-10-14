import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';
import '../core/constants/api_endpoints.dart';
import '../core/errors/app_exception.dart';

class ApiService {
  ApiService({
    required this.config,
    http.Client? client,
    void Function(String)? logger,
  }) : _client = client ?? http.Client(),
       _logger = logger ?? debugPrint;

  final AppConfig config;
  final http.Client _client;
  final void Function(String) _logger;

  Future<Object?> get(String path, {String? token}) =>
      request('GET', path, token: token);
  Future<Object?> post(String path, {Object? body, String? token}) =>
      request('POST', path, body: body, token: token);
  Future<Object?> put(String path, {Object? body, String? token}) =>
      request('PUT', path, body: body, token: token);
  Future<Object?> patch(String path, {Object? body, String? token}) =>
      request('PATCH', path, body: body, token: token);
  Future<Object?> delete(String path, {Object? body, String? token}) =>
      request('DELETE', path, body: body, token: token);

  Future<Object?> request(
    String method,
    String path, {
    Object? body,
    String? token,
  }) async {
    final watch = Stopwatch()..start();
    int? status;
    ErrorKind? failure;
    final abort = Completer<void>();
    try {
      final relative = Uri.parse(path);
      if (relative.hasScheme ||
          relative.hasAuthority ||
          path.startsWith('/') ||
          relative.pathSegments.contains('..') ||
          relative.hasFragment) {
        throw const AppException(
          ErrorKind.configuration,
          'API routes must be relative to the configured backend.',
        );
      }
      final uri = config.baseUri.resolveUri(relative);
      final request =
          http.AbortableRequest(method, uri, abortTrigger: abort.future)
            ..followRedirects = false
            ..headers['Accept'] = 'application/json';
      if (token != null) {
        if (token.isEmpty || RegExp(r'\s').hasMatch(token)) {
          throw AppException.unexpected;
        }
        request.headers['Authorization'] = 'Bearer $token';
      }
      if (body != null) {
        request.headers['Content-Type'] = 'application/json; charset=utf-8';
        request.body = jsonEncode(body);
      }
      final response =
          await (() async {
            final streamed = await _client.send(request);
            status = streamed.statusCode;
            return http.Response.fromStream(streamed);
          })().timeout(
            config.requestTimeout,
            onTimeout: () {
              abort.complete();
              throw TimeoutException('request timed out');
            },
          );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AppException.fromStatus(response.statusCode);
      }
      if (response.statusCode == 204) return null;
      final Object? data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is Map<String, dynamic>) {
        final code = data['statusCode'];
        if (code is int && code >= 400 && code <= 599) {
          throw AppException.fromStatus(code);
        }
        if (data['status'] == 'error') throw AppException.unexpected;
      }
      return data;
    } on AppException catch (error) {
      failure = error.kind;
      rethrow;
    } on TimeoutException {
      failure = ErrorKind.timeout;
      throw const AppException(
        ErrorKind.timeout,
        'The request timed out. Check your connection and try again.',
      );
    } on SocketException {
      failure = ErrorKind.network;
      throw const AppException(
        ErrorKind.network,
        'Cannot reach ALLY. Check your network and backend address.',
      );
    } on HandshakeException {
      failure = ErrorKind.network;
      throw const AppException(
        ErrorKind.network,
        'A secure connection could not be established. Check the server certificate.',
      );
    } on http.ClientException {
      failure = ErrorKind.network;
      throw const AppException(
        ErrorKind.network,
        'Cannot reach ALLY. Check your connection and try again.',
      );
    } on FormatException {
      failure = ErrorKind.unexpectedResponse;
      throw AppException.unexpected;
    } catch (_) {
      failure = ErrorKind.unknown;
      throw AppException.unknown;
    } finally {
      if (kDebugMode) {
        _logger(
          '[ALLY API] $method ${ApiEndpoints.logLabel(path)} '
          'status=${status ?? '-'} duration=${watch.elapsedMilliseconds}ms '
          'error=${failure?.name ?? 'none'}',
        );
      }
    }
  }

  void close() => _client.close();
}
