class CategoryModel {
  final int id;
  final String name;
  final String imageUrl;
  final List<SubcategoryModel> subcategories;

  CategoryModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.subcategories,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    final rawSub = json['subcategories'] is List
        ? (json['subcategories'] as List)
        : (json['subcategories'] is Map && json['subcategories']['results'] is List
            ? (json['subcategories']['results'] as List)
            : null);

    return CategoryModel(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      subcategories: rawSub
              ?.where((i) => i != null && i is Map)
              .map((i) => SubcategoryModel.fromJson(Map<String, dynamic>.from(i as Map)))
              .toList() ??
          [],
    );
  }
}

class SubcategoryModel {
  final int id;
  final String name;

  SubcategoryModel({required this.id, required this.name});

  factory SubcategoryModel.fromJson(Map<String, dynamic> json) {
    return SubcategoryModel(id: json['id'] ?? 0, name: json['name'] ?? '');
  }
}
