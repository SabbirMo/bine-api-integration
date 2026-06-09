import 'package:flutter/material.dart';
import 'package:binetatour/core/network/api_services/api_services.dart';

class StoryProvider extends ChangeNotifier {
  final ApiServices _apiServices = ApiServices();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> viewStory(int storyId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Calling the API to mark story as viewed
      await _apiServices.post(
        '/api/mobile/stories/$storyId/view/',
        requireAuth: true,
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
