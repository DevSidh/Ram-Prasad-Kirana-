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
}
