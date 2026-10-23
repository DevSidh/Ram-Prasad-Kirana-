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
  final double? weightStockKg;
  final double rating;
  final int reviewCount;
  final bool isOrganic;
  final bool isFeatured;
  final bool isBestSeller;
  final bool isVendingDrink;
  final String? vendingSection;
  final bool isWholesale;
  final bool isWholesaleItem;
  final double? wholesalePrice;
  final int wholesaleMinimumQuantity;
  final String description;
  final String? origin;
  final String imageUrl;
  final List<String> imageUrls;

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
    this.weightStockKg,
    this.rating = 5.0,
    this.reviewCount = 0,
    this.isOrganic = false,
    this.isFeatured = false,
    this.isBestSeller = false,
    this.isVendingDrink = false,
    this.vendingSection,
    this.isWholesale = false,
    this.isWholesaleItem = false,
    this.wholesalePrice,
    this.wholesaleMinimumQuantity = 1,
    required this.description,
    this.origin,
    required this.imageUrl,
    this.imageUrls = const [],
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawImageUrls = json['imageUrls'];
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
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      weightStockKg: (json['weightStockKg'] as num?)?.toDouble(),
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      reviewCount: json['reviewCount'] ?? 0,
      isOrganic: json['isOrganic'] ?? false,
      isFeatured: json['isFeatured'] ?? false,
      isBestSeller: json['isBestSeller'] ?? false,
      isVendingDrink: json['isVendingDrink'] ?? false,
      vendingSection: json['vendingSection'] as String?,
      isWholesale: json['isWholesale'] ?? false,
      isWholesaleItem: json['isWholesaleItem'] ?? false,
      wholesalePrice: (json['wholesalePrice'] as num?)?.toDouble(),
      wholesaleMinimumQuantity:
          (json['wholesaleMinimumQuantity'] as num?)?.toInt() ?? 1,
      description: json['description'] ?? '',
      origin: json['origin'],
      imageUrl: json['imageUrl'] ?? json['image'] ?? '',
      imageUrls: rawImageUrls is List
          ? rawImageUrls.whereType<String>().toList(growable: false)
          : const [],
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
      'weightStockKg': weightStockKg,
      'rating': rating,
      'reviewCount': reviewCount,
      'isOrganic': isOrganic,
      'isFeatured': isFeatured,
      'isBestSeller': isBestSeller,
      'isVendingDrink': isVendingDrink,
      'vendingSection': vendingSection,
      'isWholesale': isWholesale,
      'isWholesaleItem': isWholesaleItem,
      'wholesalePrice': wholesalePrice,
      'wholesaleMinimumQuantity': wholesaleMinimumQuantity,
      'description': description,
      'origin': origin,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
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
      weightStockKg: weightStockKg,
      rating: rating,
      reviewCount: reviewCount,
      isOrganic: isOrganic,
      isFeatured: isFeatured ?? this.isFeatured,
      isBestSeller: isBestSeller,
      isVendingDrink: isVendingDrink,
      vendingSection: vendingSection,
      isWholesale: isWholesale,
      isWholesaleItem: isWholesaleItem,
      wholesalePrice: wholesalePrice,
      wholesaleMinimumQuantity: wholesaleMinimumQuantity,
      description: description,
      origin: origin,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls,
    );
  }

  bool get isSoldByWeight =>
      !isWholesaleItem &&
      RegExp(r'^\s*\d+(?:\.\d+)?\s*(?:kg|g)\s*$', caseSensitive: false)
          .hasMatch(weight);

  int get availableWeightGrams =>
      ((weightStockKg ?? stock.toDouble()) * 1000).floor();

  bool get hasStock => isSoldByWeight ? availableWeightGrams > 0 : stock > 0;
}
