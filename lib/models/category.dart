class Category {
  final String id;
  final String name;
  final String slug;
  final String? iconName;
  final String? imageUrl;
  final int itemCount;

  Category({
    required this.id,
    required this.name,
    required this.slug,
    this.iconName,
    this.imageUrl,
    this.itemCount = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      iconName: json['iconName'],
      imageUrl: json['imageUrl'] ?? json['image'],
      itemCount: json['itemCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'iconName': iconName,
      'imageUrl': imageUrl,
      'itemCount': itemCount,
    };
  }
}
