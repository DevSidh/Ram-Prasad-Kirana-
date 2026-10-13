import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:http/http.dart' as http;

import '../core/constants.dart';

class ApiService {
  final String baseUrl;
  final http.Client _client;
  String? _authToken;

  ApiService({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? AppConstants.apiBaseUrl,
        _client = client ?? http.Client();

  void setAuthToken(String token) {
    _authToken = token;
  }

  void clearAuthToken() {
    _authToken = null;
  }

  Map<String, String> _headers() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
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
      final response = await _client
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 10));
      return _processResponse(response);
    } on ApiResponseException {
      rethrow;
    } on TimeoutException {
      throw Exception(
        'The store server at $baseUrl did not respond. Check the server and network connection.',
      );
    } catch (e) {
      throw Exception(
        'Could not reach the store server at $baseUrl. Start the backend or set API_BASE_URL to a reachable server.',
      );
    }
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await _client
          .post(uri, headers: _headers(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } on ApiResponseException {
      rethrow;
    } on TimeoutException {
      throw Exception(
        'The store server at $baseUrl did not respond. Check the server and network connection.',
      );
    } catch (e) {
      throw Exception(
        'Could not reach the store server at $baseUrl. Start the backend or set API_BASE_URL to a reachable server.',
      );
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
      final request = http.MultipartRequest(method, Uri.parse('$baseUrl$endpoint'));
      if (_authToken != null && _authToken!.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $_authToken';
      }
      request.fields.addAll(fields);
      request.files.add(http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: fileName,
      ));
      final streamed =
          await _client.send(request).timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 30));
      return _processResponse(response);
    } on ApiResponseException {
      rethrow;
    } on TimeoutException {
      throw Exception(
          'Image upload timed out. Check the server and network connection.');
    } catch (error) {
      throw Exception(
          'Could not reach the store server at $baseUrl for image upload.');
    }
  }

  Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await _client
          .patch(uri, headers: _headers(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } on ApiResponseException {
      rethrow;
    } on TimeoutException {
      throw Exception(
        'The store server at $baseUrl did not respond. Check the server and network connection.',
      );
    } catch (e) {
      throw Exception(
        'Could not reach the store server at $baseUrl. Start the backend or set API_BASE_URL to a reachable server.',
      );
    }
  }

  Future<dynamic> delete(String endpoint) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await _client
          .delete(uri, headers: _headers())
          .timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } on ApiResponseException {
      rethrow;
    } on TimeoutException {
      throw Exception(
        'The store server at $baseUrl did not respond. Check the server and network connection.',
      );
    } catch (e) {
      throw Exception(
        'Could not reach the store server at $baseUrl. Start the backend or set API_BASE_URL to a reachable server.',
      );
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
        message = response.body;
      }
    }
    throw ApiResponseException(message);
  }
}

class ApiResponseException implements Exception {
  final String message;

  const ApiResponseException(this.message);

  @override
  String toString() => message;
}
