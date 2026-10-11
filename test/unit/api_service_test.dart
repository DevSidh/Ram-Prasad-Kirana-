import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:freshharvest_grocery/services/api_service.dart';

void main() {
  test('sends the bearer token with authenticated requests', () async {
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
      'Bearer session-token',
    );
    client.close();
  });

  test('sends authenticated image uploads through the configured client',
      () async {
    http.BaseRequest? capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({'url': '/uploads/products/item.png'}),
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
      'Bearer session-token',
    );
    expect(
      capturedRequest?.headers['content-type'],
      startsWith('multipart/form-data; boundary='),
    );
    client.close();
  });
}
