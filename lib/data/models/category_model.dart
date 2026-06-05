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
    return CategoryModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      imageUrl: json['image_url'] ?? '',
      subcategories: json['subcategories'] != null
          ? (json['subcategories'] as List)
                .map((i) => SubcategoryModel.fromJson(i))
                .toList()
          : [],
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
