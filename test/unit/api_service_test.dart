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

  test('getBytes sends the token and returns the image payload', () async {
    http.Request? capturedRequest;
    final imageBytes = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]);
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response.bytes(
        imageBytes,
        200,
        headers: {'content-type': 'image/png'},
      );
    });
    final api = ApiService(
      baseUrl: 'https://store.example/api/v1',
      client: client,
    )..setAuthToken('session-token');

    final response = await api.getBytes(
      '/admin/inventory/purchase-bills/bill-1/photo',
    );

    expect(response, imageBytes);
    expect(capturedRequest?.url.path,
        '/api/v1/admin/inventory/purchase-bills/bill-1/photo');
    expect(
      capturedRequest?.headers['authorization'],
      ['Bearer', 'session-token'].join(' '),
    );
    client.close();
  });

  test('missing supplier-bill routes explain the required backend rollout',
      () async {
    final client = MockClient((request) async => http.Response(
          'Cannot GET /api/v1/admin/inventory/purchase-bills',
          404,
        ));
    final api = ApiService(
      baseUrl: 'https://store.example/api/v1',
      client: client,
    );

    await expectLater(
      api.get('/admin/inventory/purchase-bills'),
      throwsA(isA<ApiResponseException>().having(
        (error) => error.message,
        'message',
        contains('deploy the backend with supplier-bill routes'),
      )),
    );
    client.close();
  });

  test('timeout errors are not mislabeled as lost internet access', () async {
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
        isA<ApiTimeoutException>().having(
          (error) => error.message,
          'message',
          'The store server took too long to respond. Please try again.',
        ),
      ),
    );
    client.close();
  });

  test('connection errors do not assert that the device is offline', () async {
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
          'Unable to reach the store server. Check your connection or try again later.',
        ),
      ),
    );
    client.close();
  });

  test('unexpected client failures are not disguised as connection errors',
      () async {
    final client = MockClient((request) async {
      throw StateError('unexpected decoding failure');
    });
    final api = ApiService(
      baseUrl: 'https://store.example/api/v1',
      client: client,
    );

    await expectLater(
      api.get('/products'),
      throwsA(isA<StateError>()),
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
          'Billing endpoint unavailable: GET '
              '/api/v1/admin/billing/overview. Confirm the backend release '
              'and API base URL point to the expected service.',
        ),
      ),
    );
    client.close();
  });

  test('non-GET billing route errors include the method and endpoint',
      () async {
    final client = MockClient((request) async => http.Response(
          '<pre>Cannot POST /api/v1/admin/billing/sales</pre>',
          404,
          headers: {'content-type': 'text/html'},
        ));
    final api = ApiService(
      baseUrl: 'https://store.example/api/v1',
      client: client,
    );

    await expectLater(
      api.post('/admin/billing/sales', const {}),
      throwsA(
        isA<ApiResponseException>().having(
          (error) => error.message,
          'message',
          'Billing endpoint unavailable: POST '
              '/api/v1/admin/billing/sales. Confirm the backend release '
              'and API base URL point to the expected service.',
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
