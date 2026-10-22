const productShareApkUrl =
    'https://github.com/DevSidh/Ram-Prasad-Kirana-/releases/latest/download/app-release.apk';

String buildProductShareLink(String productId) {
  final encodedId = Uri.encodeComponent(productId);
  final fallback = Uri.encodeComponent(productShareApkUrl);
  return 'intent://product/$encodedId'
      '#Intent;scheme=faststore;package=com.freshharvest.grocery_app;'
      'S.browser_fallback_url=$fallback;end';
}

String? sharedProductIdFromRoute(String? routeName) {
  if (routeName == null || routeName.isEmpty) return null;
  final uri = Uri.tryParse(routeName);
  if (uri == null) return null;
  if (uri.scheme == 'faststore' && uri.host == 'product') {
    return uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
  }
  if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'product') {
    return uri.pathSegments[1];
  }
  return null;
}
