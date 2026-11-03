import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _releaseDownloadPath = '/DevSidh/Ram-Prasad-Kirana-/releases/download/';

class GitHubAppRelease {
  const GitHubAppRelease({
    required this.version,
    required this.name,
    required this.notes,
    required this.publishedAt,
    required this.downloadUrl,
    required this.fileName,
    required this.sizeBytes,
    required this.sha256,
    required this.htmlUrl,
    required this.mandatory,
  });

  final String version;
  final String name;
  final String notes;
  final DateTime? publishedAt;
  final String downloadUrl;
  final String fileName;
  final int sizeBytes;
  final String? sha256;
  final String htmlUrl;
  final bool mandatory;

  factory GitHubAppRelease.fromJson(Map<String, dynamic> json) {
    if (json['draft'] == true || json['prerelease'] == true) {
      throw const FormatException('This is not a published stable release.');
    }
    final tag = json['tag_name']?.toString() ?? '';
    final version = tag.replaceFirst(RegExp(r'^v'), '');
    if (!RegExp(r'^\d+\.\d+(?:\.\d+)?(?:[-+].*)?$').hasMatch(version)) {
      throw const FormatException('The GitHub release has an invalid version.');
    }
    final rawAssets = json['assets'];
    if (rawAssets is! List) {
      throw const FormatException('The GitHub release has no asset list.');
    }
    final apk = rawAssets.whereType<Map<String, dynamic>>().where((asset) {
      final name = asset['name']?.toString().toLowerCase() ?? '';
      final type = asset['content_type']?.toString().toLowerCase() ?? '';
      final url = Uri.tryParse(asset['browser_download_url']?.toString() ?? '');
      return name.endsWith('.apk') &&
          (type == 'application/vnd.android.package-archive' || type.isEmpty) &&
          url != null &&
          url.scheme == 'https' &&
          url.host == 'github.com' &&
          url.path.startsWith(_releaseDownloadPath);
    }).firstOrNull;
    if (apk == null) {
      throw const FormatException(
          'The latest GitHub release has no APK asset.');
    }
    final digest = apk['digest']?.toString();
    final sha256 = digest != null && digest.startsWith('sha256:')
        ? digest.substring('sha256:'.length).toLowerCase()
        : null;
    if (sha256 != null && !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256)) {
      throw const FormatException('The APK checksum is malformed.');
    }
    final publishedAt =
        DateTime.tryParse(json['published_at']?.toString() ?? '');
    final htmlUrl = json['html_url']?.toString() ?? '';
    final releaseUri = Uri.tryParse(htmlUrl);
    if (releaseUri?.scheme != 'https' ||
        releaseUri?.host != 'github.com' ||
        !(releaseUri?.path.startsWith(
              '/DevSidh/Ram-Prasad-Kirana-/releases/tag/',
            ) ??
            false)) {
      throw const FormatException('The GitHub release link is invalid.');
    }
    return GitHubAppRelease(
      version: version,
      name: json['name']?.toString().trim().isNotEmpty == true
          ? json['name'].toString()
          : 'FastStore $version',
      notes: json['body']?.toString().trim() ?? '',
      publishedAt: publishedAt,
      downloadUrl: apk['browser_download_url'].toString(),
      fileName: apk['name'].toString(),
      sizeBytes: apk['size'] is num ? (apk['size'] as num).toInt() : 0,
      sha256: sha256,
      htmlUrl: htmlUrl,
      mandatory: _isVerifiedMandatoryPolicy(json, version),
    );
  }

  static bool _isVerifiedMandatoryPolicy(
    Map<String, dynamic> release,
    String releaseVersion,
  ) {
    final policy = release['_faststore_verified_update_policy'];
    return policy is Map<String, dynamic> &&
        policy['schemaVersion'] == 1 &&
        policy['appId'] == 'com.freshharvest.grocery_app' &&
        policy['releaseVersion'] == releaseVersion &&
        policy['mandatory'] == true;
  }
}

class GitHubReleaseService {
  GitHubReleaseService({Dio? dio}) : _dio = dio ?? _createDio();

  static const _apiUrl =
      'https://api.github.com/repos/DevSidh/Ram-Prasad-Kirana-/releases/latest';
  static const _cacheKey = 'faststore_github_latest_release_v1';
  static const _etagKey = 'faststore_github_latest_release_etag_v1';

  final Dio _dio;

  static Dio _createDio() => Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 8),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'User-Agent': 'FastStore-Android-App',
        },
        validateStatus: (status) => status == 304 || (status ?? 500) < 400,
      ));

  Future<GitHubAppRelease> fetchLatest() async {
    final preferences = await SharedPreferences.getInstance();
    final etag = preferences.getString(_etagKey);
    final cachedRaw = preferences.getString(_cacheKey);
    var retryUnverifiedPolicyAsset = false;
    if (cachedRaw != null) {
      try {
        final cachedJson = jsonDecode(cachedRaw);
        if (cachedJson is Map<String, dynamic> &&
            cachedJson['_faststore_verified_update_policy'] == null &&
            cachedJson['assets'] is List) {
          retryUnverifiedPolicyAsset = (cachedJson['assets'] as List)
              .whereType<Map<String, dynamic>>()
              .any(
                (asset) => asset['name'] == 'faststore-update-policy.json',
              );
        }
      } catch (_) {
        // An invalid cache is ignored and the normal GitHub request proceeds.
      }
    }
    try {
      final response = await _dio.get<dynamic>(
        _apiUrl,
        options: Options(
          headers: {
            if (etag != null && !retryUnverifiedPolicyAsset)
              'If-None-Match': etag,
          },
          responseType: ResponseType.json,
        ),
      );
      dynamic body = response.data;
      if (response.statusCode == 304) {
        final cached = preferences.getString(_cacheKey);
        if (cached == null) {
          throw const FormatException(
              'GitHub returned an empty cached release.');
        }
        body = jsonDecode(cached);
      } else {
        if (body is! Map<String, dynamic>) {
          throw const FormatException('GitHub returned an invalid release.');
        }
        final policy = await _fetchExplicitPolicy(
          body['assets'],
          body['tag_name']?.toString().replaceFirst(RegExp(r'^v'), ''),
        );
        body = {
          ...body,
          if (policy != null) '_faststore_verified_update_policy': policy,
        };
        await preferences.setString(_cacheKey, jsonEncode(body));
        final newEtag = response.headers.value('etag');
        if (newEtag != null) await preferences.setString(_etagKey, newEtag);
      }
      if (body is! Map<String, dynamic>) {
        throw const FormatException('GitHub returned an invalid release.');
      }
      return GitHubAppRelease.fromJson(body);
    } catch (_) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _fetchExplicitPolicy(
    Object? rawAssets,
    String? releaseVersion,
  ) async {
    if (rawAssets is! List) return null;
    final policyAsset = rawAssets.whereType<Map<String, dynamic>>().firstWhere(
          (asset) => asset['name'] == 'faststore-update-policy.json',
          orElse: () => const <String, dynamic>{},
        );
    if (policyAsset.isEmpty) return null;
    final url = Uri.tryParse(
      policyAsset['browser_download_url']?.toString() ?? '',
    );
    if (url?.scheme != 'https' ||
        url?.host != 'github.com' ||
        !(url?.path.startsWith(_releaseDownloadPath) ?? false) ||
        (policyAsset['size'] is num &&
            (policyAsset['size'] as num).toInt() > 128 * 1024)) {
      return null;
    }
    try {
      final response = await _dio.get<dynamic>(
        url.toString(),
        options: Options(
          responseType: ResponseType.json,
          headers: const {'Accept': 'application/json'},
        ),
      );
      final policy = response.data;
      final version = policy is Map<String, dynamic>
          ? policy['releaseVersion']?.toString()
          : null;
      if (policy is! Map<String, dynamic> ||
          policy['schemaVersion'] != 1 ||
          policy['appId'] != 'com.freshharvest.grocery_app' ||
          policy['mandatory'] is! bool ||
          version == null ||
          version != releaseVersion ||
          !RegExp(r'^\d+\.\d+(?:\.\d+)?(?:[-+].*)?$').hasMatch(version)) {
        return null;
      }
      return {
        'schemaVersion': 1,
        'appId': 'com.freshharvest.grocery_app',
        'releaseVersion': version,
        'mandatory': policy['mandatory'] == true,
      };
    } catch (_) {
      return null;
    }
  }

  Future<GitHubAppRelease?> readCachedRelease() async {
    final preferences = await SharedPreferences.getInstance();
    final cached = preferences.getString(_cacheKey);
    if (cached == null) return null;
    try {
      final decoded = jsonDecode(cached);
      if (decoded is! Map<String, dynamic>) return null;
      return GitHubAppRelease.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}
