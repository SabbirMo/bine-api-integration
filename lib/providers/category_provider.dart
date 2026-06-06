import 'package:flutter/material.dart';
import 'package:binetatour/core/network/api_services/api_services.dart';
import 'package:binetatour/data/models/category_model.dart';

class CategoryProvider extends ChangeNotifier {
  final ApiServices _apiServices = ApiServices();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<CategoryModel> _categories = [];
  List<CategoryModel> get categories => _categories;

  Future<void> fetchCategories() async {
    if (_categories.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }
    _errorMessage = null;

    try {
      final response = await _apiServices.get(
        '/api/mobile/categories/',
        requireAuth: false,
      );

      final dynamic data = response.data;

      if (data is List) {
        _categories = data.map((e) => CategoryModel.fromJson(e)).toList();
      } else if (data is Map<String, dynamic> && data.containsKey('data')) {
        _categories = (data['data'] as List)
            .map((e) => CategoryModel.fromJson(e))
            .toList();
      } else {
        _categories = [];
      }

      // _categories.insert(
      //   0,
      //   CategoryModel(
      //     id: -1,
      //     name: "Tous",
      //     imageUrl: "assets/icon/tous.svg",
      //     subcategories: [],
      //   ),
      // );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
