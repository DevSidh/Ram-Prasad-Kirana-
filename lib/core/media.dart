import 'constants.dart';

String resolveProductImageUrl(String imageUrl) {
  final value = imageUrl.trim();
  if (value.isEmpty) return '';

  final uri = Uri.tryParse(value);
  if (uri == null) return '';
  if (uri.hasScheme && uri.host.isNotEmpty) {
    if (!_isLocalImageHost(uri.host)) return uri.toString();
    final apiUri = Uri.tryParse(AppConstants.apiBaseUrl);
    if (apiUri == null || apiUri.host.isEmpty) return '';
    final apiOrigin = apiUri.replace(
      path: '/',
      query: null,
      fragment: null,
    );
    return apiOrigin
        .replace(
          path: uri.path,
          query: uri.hasQuery ? uri.query : null,
          fragment: uri.hasFragment ? uri.fragment : null,
        )
        .toString();
  }

  final apiUri = Uri.tryParse(AppConstants.apiBaseUrl);
  if (apiUri == null || apiUri.host.isEmpty) return '';

  final origin = apiUri.replace(
    path: '/',
    query: null,
    fragment: null,
  );
  final path = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
  return origin.resolveUri(uri.replace(path: path)).toString();
}

bool _isLocalImageHost(String host) {
  final normalizedHost = host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
  return normalizedHost == 'localhost' ||
      normalizedHost == '127.0.0.1' ||
      normalizedHost == '0.0.0.0' ||
      normalizedHost == '::1';
}

String highResolutionImageUrl(String imageUrl) {
  return optimizedProductImageUrl(imageUrl);
}

String optimizedProductImageUrl(
  String imageUrl, {
  int targetWidth = 800,
}) {
  final resolvedUrl = resolveProductImageUrl(imageUrl);
  final uri = Uri.tryParse(resolvedUrl);
  if (uri == null || uri.host != 'images.unsplash.com') return resolvedUrl;

  final queryParameters = Map<String, String>.from(uri.queryParameters)
    ..remove('dpr')
    ..remove('auto')
    ..['w'] = '${targetWidth.clamp(320, 1400)}'
    ..['q'] = '80'
    ..['fm'] = 'jpg';

  return uri
      .replace(
        queryParameters: queryParameters,
      )
      .toString();
}
