import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:binetatour/core/network/api_services/api_services.dart';
import 'package:binetatour/data/models/home_response_model.dart';

class HomeProvider extends ChangeNotifier {
  final ApiServices _apiServices = ApiServices();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  HomeResponseModel? _homeData;
  HomeResponseModel? get homeData => _homeData;

  Future<void> fetchHomeData() async {
    if (_homeData == null) {
      _isLoading = true;
      notifyListeners();
    }
    _errorMessage = null;

    try {
      // Assuming home API doesn't require strict auth to view banners and products
      final response = await _apiServices.get(
        '/api/mobile/home/',
        requireAuth: false,
      );

      final dynamic data = response.data;

      debugPrint(
        "================ STORY CATEGORIES API RESPONSE ================",
      );
      try {
        const encoder = JsonEncoder.withIndent('  ');
        if (data is Map<String, dynamic> &&
            data.containsKey('story_categories')) {
          debugPrint(encoder.convert(data['story_categories']));
        } else {
          debugPrint(encoder.convert(data));
        }
      } catch (_) {
        debugPrint("Raw Response: $data");
      }
      debugPrint(
        "==============================================================",
      );

      // If the backend wraps the response in a "data" field, we extract it.
      // Based on the provided JSON, it seems it's directly at the root.
      // We will handle both cases gracefully.
      final Map<String, dynamic> jsonMap =
          data is Map<String, dynamic> && data.containsKey('banner')
          ? data
          : (data['data'] ?? {});

      _homeData = HomeResponseModel.fromJson(jsonMap);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
