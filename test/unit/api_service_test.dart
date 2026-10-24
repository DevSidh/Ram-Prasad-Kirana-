import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:freshharvest_grocery/services/api_service.dart';

void main() {
  test('authenticated requests send the session token as a bearer credential',
      () async {
    http.Request? capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(jsonEncode({'ok': true}), 200);
    });
    final api = ApiService(
      baseUrl: 'https://store.example/api/v1',
      client: client,
    )..setAuthToken('session-token');

    await api.get('/account/profile');

    expect(
      capturedRequest?.headers['authorization'],
      ['Bearer', 'session-token'].join(' '),
    );
    client.close();
  });

  test('authenticated image uploads send the bearer credential', () async {
    http.BaseRequest? capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({'url': '/api/v1/images/image-1'}),
        200,
      );
    });
    final api = ApiService(
      baseUrl: 'https://store.example/api/v1',
      client: client,
    )..setAuthToken('session-token');

    await api.postFile(
      '/admin/uploads/images',
      fieldName: 'image',
      bytes: Uint8List.fromList([1, 2, 3]),
      fileName: 'item.png',
    );

    expect(capturedRequest?.method, 'POST');
    expect(
      capturedRequest?.headers['authorization'],
      ['Bearer', 'session-token'].join(' '),
    );
    expect(
      capturedRequest?.headers['content-type'],
      startsWith('multipart/form-data; boundary='),
    );
    client.close();
  });

  test('timeout errors give a short connection message without server details',
      () async {
    final client = MockClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return http.Response(jsonEncode({'ok': true}), 200);
    });
    final api = ApiService(
      baseUrl: 'https://store.example/api/v1',
      client: client,
      requestTimeout: const Duration(milliseconds: 1),
    );

    await expectLater(
      api.get('/products'),
      throwsA(
        isA<ApiNetworkException>().having(
          (error) => error.message,
          'message',
          'No internet connection. Check your connection and try again.',
        ),
      ),
    );
    client.close();
  });

  test('transport errors never expose backend URLs or exception details',
      () async {
    final client = MockClient((request) async {
      throw http.ClientException('connection aborted', request.url);
    });
    final api = ApiService(
      baseUrl: 'https://store.example/api/v1',
      client: client,
    );

    await expectLater(
      api.get('/products'),
      throwsA(
        isA<ApiNetworkException>().having(
          (error) => error.toString(),
          'message',
          'No internet connection. Check your connection and try again.',
        ),
      ),
    );
    client.close();
  });

  test('HTML route errors are shown as concise actionable text', () async {
    final client = MockClient((request) async => http.Response(
          '<html><body><pre>Cannot GET '
          '/api/v1/admin/billing/overview</pre></body></html>',
          404,
          headers: {'content-type': 'text/html'},
        ));
    final api = ApiService(
      baseUrl: 'https://store.example/api/v1',
      client: client,
    );

    await expectLater(
      api.get('/admin/billing/overview'),
      throwsA(
        isA<ApiResponseException>().having(
          (error) => error.message,
          'message',
          'Billing is unavailable on the connected server: '
              '/api/v1/admin/billing/overview was not found. '
              'The backend release may need updating.',
        ),
      ),
    );
    client.close();
  });

  test('other HTML errors do not leak markup into the error message', () async {
    final client = MockClient((request) async => http.Response(
          '<html><body><h1>Service unavailable</h1></body></html>',
          503,
          headers: {'content-type': 'text/html'},
        ));
    final api = ApiService(
      baseUrl: 'https://store.example/api/v1',
      client: client,
    );

    await expectLater(
      api.get('/products'),
      throwsA(
        isA<ApiResponseException>().having(
          (error) => error.message,
          'message',
          'Service unavailable',
        ),
      ),
    );
    client.close();
  });
}
