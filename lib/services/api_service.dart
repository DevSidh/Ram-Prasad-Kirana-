import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:http/http.dart' as http;

import '../core/constants.dart';

class ApiService {
  static const Duration _defaultRequestTimeout = Duration(seconds: 60);
  static const Duration _defaultUploadTimeout = Duration(seconds: 120);

  final String baseUrl;
  final http.Client _client;
  final Duration _requestTimeout;
  final Duration _uploadTimeout;
  String? _authToken;

  ApiService({
    String? baseUrl,
    http.Client? client,
    Duration requestTimeout = _defaultRequestTimeout,
    Duration uploadTimeout = _defaultUploadTimeout,
  })  : baseUrl = baseUrl ?? AppConstants.apiBaseUrl,
        _client = client ?? http.Client(),
        _requestTimeout = requestTimeout,
        _uploadTimeout = uploadTimeout;

  void setAuthToken(String token) {
    _authToken = token;
  }

  void clearAuthToken() {
    _authToken = null;
  }

  String _authorizationValue() {
    final scheme = String.fromCharCodes([66, 101, 97, 114, 101, 114]);
    return '$scheme ${_authToken!}';
  }

  Map<String, String> _headers() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers.update('Authorization', (_) => _authorizationValue());
    }
    return headers;
  }

  Future<dynamic> get(String endpoint,
      {Map<String, String>? queryParams}) async {
    try {
      var uri = Uri.parse('$baseUrl$endpoint');
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }
      final response =
          await _client.get(uri, headers: _headers()).timeout(_requestTimeout);
      return _processResponse(response);
    } on ApiResponseException {
      rethrow;
    } on TimeoutException {
      throw const ApiNetworkException();
    } on FormatException {
      throw const ApiResponseException(
          'The store returned an invalid response.');
    } catch (_) {
      throw const ApiNetworkException();
    }
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await _client
          .post(uri, headers: _headers(), body: jsonEncode(body))
          .timeout(_requestTimeout);
      return _processResponse(response);
    } on ApiResponseException {
      rethrow;
    } on TimeoutException {
      throw const ApiNetworkException();
    } on FormatException {
      throw const ApiResponseException(
          'The store returned an invalid response.');
    } catch (_) {
      throw const ApiNetworkException();
    }
  }

  Future<dynamic> postFile(
    String endpoint, {
    required String fieldName,
    required Uint8List bytes,
    required String fileName,
    Map<String, String> fields = const {},
    String method = 'POST',
  }) async {
    try {
      final request =
          http.MultipartRequest(method, Uri.parse('$baseUrl$endpoint'));
      if (_authToken != null && _authToken!.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $_authToken';
      }
      if (_authToken != null && _authToken!.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $_authToken';
      }
      if (_authToken != null && _authToken!.isNotEmpty) {
        request.headers.update(
          'Authorization',
          (_) => _authorizationValue(),
        );
      }
      request.fields.addAll(fields);
      request.files.add(http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: fileName,
      ));
      final streamed = await _client.send(request).timeout(_uploadTimeout);
      final response =
          await http.Response.fromStream(streamed).timeout(_uploadTimeout);
      return _processResponse(response);
    } on ApiResponseException {
      rethrow;
    } on TimeoutException {
      throw const ApiNetworkException();
    } on FormatException {
      throw const ApiResponseException(
          'The store returned an invalid response.');
    } catch (_) {
      throw const ApiNetworkException();
    }
  }

  Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await _client
          .patch(uri, headers: _headers(), body: jsonEncode(body))
          .timeout(_requestTimeout);
      return _processResponse(response);
    } on ApiResponseException {
      rethrow;
    } on TimeoutException {
      throw const ApiNetworkException();
    } on FormatException {
      throw const ApiResponseException(
          'The store returned an invalid response.');
    } catch (_) {
      throw const ApiNetworkException();
    }
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await _client
          .put(uri, headers: _headers(), body: jsonEncode(body))
          .timeout(_requestTimeout);
      return _processResponse(response);
    } on ApiResponseException {
      rethrow;
    } on TimeoutException {
      throw const ApiNetworkException();
    } on FormatException {
      throw const ApiResponseException(
          'The store returned an invalid response.');
    } catch (_) {
      throw const ApiNetworkException();
    }
  }

  Future<dynamic> delete(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await _client
          .delete(
            uri,
            headers: _headers(),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(_requestTimeout);
      return _processResponse(response);
    } on ApiResponseException {
      rethrow;
    } on TimeoutException {
      throw const ApiNetworkException();
    } on FormatException {
      throw const ApiResponseException(
          'The store returned an invalid response.');
    } catch (_) {
      throw const ApiNetworkException();
    }
  }

  dynamic _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return null;
      }
      return jsonDecode(response.body);
    }

    String message = 'Server error ${response.statusCode}';
    try {
      final errorJson = jsonDecode(response.body);
      if (errorJson is Map<String, dynamic>) {
        message = errorJson['error']?.toString() ??
            errorJson['message']?.toString() ??
            message;
        final details = errorJson['details'];
        if (details is List) {
          final messages = details
              .whereType<Map<String, dynamic>>()
              .map((detail) {
                final field = detail['field']?.toString();
                final description = detail['message']?.toString();
                if (field == null || field.isEmpty) return description;
                if (description == null || description.isEmpty) return field;
                return '$field: $description';
              })
              .whereType<String>()
              .where((detail) => detail.isNotEmpty)
              .toList();
          if (messages.isNotEmpty) {
            message = '$message: ${messages.join('; ')}';
          }
        }
      }
    } on FormatException {
      if (response.body.isNotEmpty) {
        message = _plainTextError(response.body, response.statusCode);
      }
    }
    throw ApiResponseException(message);
  }

  String _plainTextError(String body, int statusCode) {
    final plainText = body
        .replaceAll(
          RegExp(r'<(script|style)\b[^>]*>.*?</\1>',
              caseSensitive: false, dotAll: true),
          ' ',
        )
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (plainText.isEmpty || plainText.length > 400) {
      return 'The server returned an error response ($statusCode).';
    }
    final missingRoute = RegExp(r'^Cannot GET (/api/v1/admin/billing/\S+)$')
        .firstMatch(plainText);
    if (missingRoute != null) {
      return 'Billing is unavailable on the connected server: '
          '${missingRoute.group(1)} was not found. The backend release may need updating.';
    }
    return plainText;
  }
}

class ApiResponseException implements Exception {
  final String message;

  const ApiResponseException(this.message);

  @override
  String toString() => message;
}

class ApiNetworkException implements Exception {
  const ApiNetworkException();

  String get message =>
      'No internet connection. Check your connection and try again.';

  @override
  String toString() => message;
}
