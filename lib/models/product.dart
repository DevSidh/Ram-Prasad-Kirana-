class Product {
  final String id;
  final String name;
  final String? brand;
  final String categoryId;
  final String? categoryName;
  final String? categorySlug;
  final double price;
  final double? originalPrice;
  final int discountPercent;
  final String weight;
  final int stock;
  final double rating;
  final int reviewCount;
  final bool isOrganic;
  final bool isFeatured;
  final bool isBestSeller;
  final bool isVendingDrink;
  final bool isWholesale;
  final bool isWholesaleItem;
  final double? wholesalePrice;
  final int wholesaleMinimumQuantity;
  final String description;
  final String? origin;
  final String imageUrl;

  Product({
    required this.id,
    required this.name,
    this.brand,
    required this.categoryId,
    this.categoryName,
    this.categorySlug,
    required this.price,
    this.originalPrice,
    this.discountPercent = 0,
    required this.weight,
    required this.stock,
    this.rating = 5.0,
    this.reviewCount = 0,
    this.isOrganic = false,
    this.isFeatured = false,
    this.isBestSeller = false,
    this.isVendingDrink = false,
    this.isWholesale = false,
    this.isWholesaleItem = false,
    this.wholesalePrice,
    this.wholesaleMinimumQuantity = 1,
    required this.description,
    this.origin,
    required this.imageUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      brand: json['brand'],
      categoryId: json['categoryId'] ?? '',
      categoryName: json['categoryName'],
      categorySlug: json['categorySlug'],
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      originalPrice: (json['originalPrice'] as num?)?.toDouble(),
      discountPercent: json['discountPercent'] ?? 0,
      weight: json['unitLabel'] ?? json['weight'] ?? json['unit'] ?? '1 pc',
      stock: json['stock'] ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      reviewCount: json['reviewCount'] ?? 0,
      isOrganic: json['isOrganic'] ?? false,
      isFeatured: json['isFeatured'] ?? false,
      isBestSeller: json['isBestSeller'] ?? false,
      isVendingDrink: json['isVendingDrink'] ?? false,
      isWholesale: json['isWholesale'] ?? false,
      isWholesaleItem: json['isWholesaleItem'] ?? false,
      wholesalePrice: (json['wholesalePrice'] as num?)?.toDouble(),
      wholesaleMinimumQuantity:
          (json['wholesaleMinimumQuantity'] as num?)?.toInt() ?? 1,
      description: json['description'] ?? '',
      origin: json['origin'],
      imageUrl: json['imageUrl'] ?? json['image'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'categorySlug': categorySlug,
      'price': price,
      'originalPrice': originalPrice,
      'discountPercent': discountPercent,
      'weight': weight,
      'stock': stock,
      'rating': rating,
      'reviewCount': reviewCount,
      'isOrganic': isOrganic,
      'isFeatured': isFeatured,
      'isBestSeller': isBestSeller,
      'isVendingDrink': isVendingDrink,
      'isWholesale': isWholesale,
      'isWholesaleItem': isWholesaleItem,
      'wholesalePrice': wholesalePrice,
      'wholesaleMinimumQuantity': wholesaleMinimumQuantity,
      'description': description,
      'origin': origin,
      'imageUrl': imageUrl,
    };
  }

  Product copyWith({bool? isFeatured, String? imageUrl}) {
    return Product(
      id: id,
      name: name,
      brand: brand,
      categoryId: categoryId,
      categoryName: categoryName,
      categorySlug: categorySlug,
      price: price,
      originalPrice: originalPrice,
      discountPercent: discountPercent,
      weight: weight,
      stock: stock,
      rating: rating,
      reviewCount: reviewCount,
      isOrganic: isOrganic,
      isFeatured: isFeatured ?? this.isFeatured,
      isBestSeller: isBestSeller,
      isVendingDrink: isVendingDrink,
      isWholesale: isWholesale,
      isWholesaleItem: isWholesaleItem,
      wholesalePrice: wholesalePrice,
      wholesaleMinimumQuantity: wholesaleMinimumQuantity,
      description: description,
      origin: origin,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
