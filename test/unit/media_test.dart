import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/core/constants.dart';
import 'package:freshharvest_grocery/core/media.dart';

void main() {
  group('release API configuration', () {
    test('accepts an HTTPS deployment API URL', () {
      expect(
        AppConstants.isProductionApiUrl(
            'https://api.ramprasadstore.com/api/v1'),
        isTrue,
      );
    });

    test('rejects local, insecure, and placeholder API URLs', () {
      for (final url in [
        'http://api.ramprasadstore.com/api/v1',
        'https://localhost/api/v1',
        'https://127.0.0.1/api/v1',
        'https://api.example.invalid/api/v1',
        'https://api.freshharvest.test/api/v1',
        'https://YOUR-API-HOST/api/v1',
      ]) {
        expect(AppConstants.isProductionApiUrl(url), isFalse, reason: url);
      }
    });
  });

  group('product image URLs', () {
    test('resolves backend upload paths against the API host', () {
      final apiUri = Uri.parse(AppConstants.apiBaseUrl);
      final expected = apiUri
          .replace(path: '/', query: null, fragment: null)
          .resolve('/uploads/product-image.webp')
          .toString();

      expect(
        resolveProductImageUrl('/uploads/product-image.webp'),
        expected,
      );
    });

    test('resolves versioned backend image paths without dropping cache keys',
        () {
      final expected = Uri.parse(AppConstants.apiBaseUrl)
          .replace(path: '/', query: null, fragment: null)
          .resolve('/api/v1/products/p-1/image?v=1730000000000')
          .toString();

      expect(
        optimizedProductImageUrl(
          '/api/v1/products/p-1/image?v=1730000000000',
        ),
        expected,
      );
    });

    test('keeps absolute image URLs intact', () {
      const imageUrl = 'https://cdn.example.com/items/apples.webp';
      expect(resolveProductImageUrl(imageUrl), imageUrl);
    });

    test('requests the original image only for the featured product carousel',
        () {
      expect(
        Uri.parse(originalCarouselProductImageUrl(
          'https://store.example/api/v1/products/p-1/image?v=42',
        )).queryParameters,
        {'v': '42', 'original': '1'},
      );
      const artworkUrl = 'https://cdn.example.com/promo/banner.webp';
      expect(originalCarouselProductImageUrl(artworkUrl), artworkUrl);
    });

    test('rewrites saved localhost uploads to the configured API host', () {
      final apiUri = Uri.parse(AppConstants.apiBaseUrl);
      final expectedUrl = apiUri
          .replace(path: '/uploads/product-image.jpg', query: 'v=2')
          .toString();

      for (final host in ['localhost', '127.0.0.1', '0.0.0.0', '[::1]']) {
        expect(
          resolveProductImageUrl(
            'http://$host:4000/uploads/product-image.jpg?v=2',
          ),
          expectedUrl,
          reason: 'Localhost image host $host should resolve to the API host.',
        );
      }
    });

    test('requests a display-sized optimized Unsplash image', () {
      final optimized = Uri.parse(
        optimizedProductImageUrl(
          'https://images.unsplash.com/photo-123?w=600&dpr=2&q=88',
          targetWidth: 540,
        ),
      );

      expect(optimized.queryParameters['w'], '540');
      expect(optimized.queryParameters['q'], '80');
      expect(optimized.queryParameters['fm'], 'jpg');
      expect(optimized.queryParameters.containsKey('auto'), isFalse);
      expect(optimized.queryParameters.containsKey('dpr'), isFalse);
    });
  });
}
