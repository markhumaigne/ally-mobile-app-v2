import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ally_mobile_app/core/config/app_config.dart';
import 'package:ally_mobile_app/core/errors/app_exception.dart';
import 'package:ally_mobile_app/services/api_service.dart';
import 'support/fixtures.dart';

Matcher kind(ErrorKind value) =>
    isA<AppException>().having((e) => e.kind, 'kind', value);

void main() {
  const config = AppConfig(apiBaseUrl: 'https://example.test/api/v1');
  for (final entry in {
    400: ErrorKind.invalidRequest,
    401: ErrorKind.unauthorized,
    402: ErrorKind.inactiveSubscription,
    403: ErrorKind.forbidden,
    404: ErrorKind.notFound,
    429: ErrorKind.rateLimited,
    500: ErrorKind.server,
    503: ErrorKind.server,
    504: ErrorKind.timeout,
  }.entries) {
    test('maps HTTP ${entry.key} even with a non-JSON error body', () async {
      final api = ApiService(
        config: config,
        client: MockClient(
          (_) async => http.Response('<html>private</html>', entry.key),
        ),
      );
      addTearDown(api.close);
      await expectLater(api.get('route'), throwsA(kind(entry.value)));
    });
  }
  test('maps transport errors and malformed success payloads', () async {
    final network = ApiService(
      config: config,
      client: MockClient((_) async => throw http.ClientException('sensitive')),
    );
    final malformed = ApiService(
      config: config,
      client: MockClient((_) async => http.Response('not-json', 200)),
    );
    addTearDown(network.close);
    addTearDown(malformed.close);
    await expectLater(network.get('route'), throwsA(kind(ErrorKind.network)));
    await expectLater(
      malformed.get('route'),
      throwsA(kind(ErrorKind.unexpectedResponse)),
    );
  });
  test('times out pending requests', () async {
    final pending = Completer<http.Response>();
    final api = ApiService(
      config: const AppConfig(
        apiBaseUrl: 'https://example.test/api',
        requestTimeout: Duration(milliseconds: 10),
      ),
      client: MockClient((_) => pending.future),
    );
    addTearDown(api.close);
    await expectLater(api.get('route'), throwsA(kind(ErrorKind.timeout)));
    pending.complete(http.Response('{}', 200));
  });
  test('handles legacy HTTP 200 error envelopes', () async {
    final api = ApiService(
      config: config,
      client: MockClient(
        (_) async => http.Response('{"status":"error","statusCode":403}', 200),
      ),
    );
    addTearDown(api.close);
    await expectLater(api.get('route'), throwsA(kind(ErrorKind.forbidden)));
  });
  test(
    'supports methods, JSON bodies, bearer headers, and no-content responses',
    () async {
      final requests = <http.Request>[];
      final api = ApiService(
        config: config,
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('', 204);
        }),
      );
      addTearDown(api.close);
      await api.get('route');
      await api.post('route', body: {'hello': 'world'}, token: 'test-secret');
      await api.put('route', body: {});
      await api.patch('route', body: {});
      await api.delete('route');
      expect(requests.map((r) => r.method), [
        'GET',
        'POST',
        'PUT',
        'PATCH',
        'DELETE',
      ]);
      expect(requests[1].headers['Authorization'], 'Bearer test-secret');
      expect(jsonDecode(requests[1].body), {'hello': 'world'});
      expect(requests[0].url.toString(), 'https://example.test/api/v1/route');
      expect(requests[1].followRedirects, isFalse);
    },
  );
  test(
    'logs contain no credentials, host, UUID, user data or response body',
    () async {
      final logs = <String>[];
      final api = ApiService(
        config: config,
        logger: logs.add,
        client: MockClient(
          (_) async => http.Response('{"private":"private-response"}', 200),
        ),
      );
      addTearDown(api.close);
      await api.post(
        'embed/config/$agentId',
        token: 'private-token',
        body: {'userId': 'private-user'},
      );
      final output = logs.join();
      expect(output, contains('POST embed/config/:agentId'));
      for (final secret in [
        agentId,
        'private-token',
        'private-user',
        'private-response',
        'example.test',
      ]) {
        expect(output, isNot(contains(secret)));
      }
    },
  );
  test(
    'rejects invalid configuration and cross-origin routes before a request',
    () async {
      for (final base in [
        '',
        'ftp://example.test',
        'https://user:pass@example.test',
        'https://example.test?token=secret',
      ]) {
        final api = ApiService(
          config: AppConfig(apiBaseUrl: base),
          client: MockClient((_) async => fail('must not request')),
        );
        addTearDown(api.close);
        await expectLater(
          api.get('route'),
          throwsA(kind(ErrorKind.configuration)),
        );
      }
      final api = ApiService(config: config);
      addTearDown(api.close);
      for (final path in ['https://elsewhere.test', '/route', '../route']) {
        await expectLater(
          api.get(path),
          throwsA(kind(ErrorKind.configuration)),
        );
      }
      expect(
        const AppConfig(
          apiBaseUrl: 'http://10.0.2.2:3000/api/v1',
          allowInsecureHttp: false,
        ).configurationError?.kind,
        ErrorKind.configuration,
      );
    },
  );
}
