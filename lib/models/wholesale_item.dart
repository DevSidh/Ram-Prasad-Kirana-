import 'product.dart';

class WholesaleItem {
  final String id;
  final String name;
  final String sku;
  final String categoryId;
  final String? categoryName;
  final String? categorySlug;
  final String? brand;
  final double price;
  final double rating;
  final int reviewCount;
  final int stock;
  final int minimumQuantity;
  final String unitLabel;
  final String description;
  final String? origin;
  final String imageUrl;

  const WholesaleItem({
    required this.id,
    required this.name,
    required this.sku,
    required this.categoryId,
    this.categoryName,
    this.categorySlug,
    this.brand,
    required this.price,
    this.rating = 0,
    this.reviewCount = 0,
    required this.stock,
    required this.minimumQuantity,
    required this.unitLabel,
    required this.description,
    this.origin,
    required this.imageUrl,
  });

  factory WholesaleItem.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    final stock = json['stock'];
    final minimum = json['minimumQuantity'];
    final price = json['price'];
    return WholesaleItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      categoryId: json['categoryId']?.toString() ??
          (category is Map<String, dynamic>
              ? category['id']?.toString()
              : null) ??
          '',
      categoryName: category is Map<String, dynamic>
          ? category['name']?.toString()
          : json['categoryName']?.toString(),
      categorySlug: category is Map<String, dynamic>
          ? category['slug']?.toString()
          : json['categorySlug']?.toString(),
      brand: json['brand']?.toString(),
      price: price is num ? price.toDouble() : 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      stock: stock is num ? stock.toInt() : 0,
      minimumQuantity: minimum is num ? minimum.toInt() : 1,
      unitLabel: json['unitLabel']?.toString() ?? '1 pc',
      description: json['description']?.toString() ?? '',
      origin: json['origin']?.toString(),
      imageUrl: json['imageUrl']?.toString() ?? '',
    );
  }

  Product toProduct() => Product(
        id: id,
        name: name,
        brand: brand,
        categoryId: categoryId,
        categoryName: categoryName,
        categorySlug: categorySlug,
        price: price,
        rating: rating,
        reviewCount: reviewCount,
        weight: unitLabel,
        stock: stock,
        isWholesale: true,
        isWholesaleItem: true,
        wholesalePrice: price,
        wholesaleMinimumQuantity: minimumQuantity,
        description: description,
        origin: origin,
        imageUrl: imageUrl,
      );
}
