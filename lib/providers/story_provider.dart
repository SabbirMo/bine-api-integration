import 'package:flutter/material.dart';
import 'package:binetatour/core/network/api_services/api_services.dart';

class StoryProvider extends ChangeNotifier {
  final ApiServices _apiServices = ApiServices();

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> viewStory(int storyId) async {
    try {
      await _apiServices.post(
        '/api/mobile/stories/$storyId/view/',
        requireAuth: true,
      );
    } catch (e) {
      _errorMessage = e.toString();
    }
  }
}
