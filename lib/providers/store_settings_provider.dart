import 'package:flutter/material.dart';
import 'package:binetatour/core/network/api_services/api_services.dart';
import 'package:binetatour/data/models/store_settings_model.dart';

class StoreSettingsProvider extends ChangeNotifier {
  final ApiServices _apiServices = ApiServices();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  StoreSettingsModel? _storeSettings;
  StoreSettingsModel? get storeSettings => _storeSettings;

  Future<void> fetchStoreSettings() async {
    if (_storeSettings == null) {
      _isLoading = true;
      notifyListeners();
    }
    _errorMessage = null;

    try {
      final response = await _apiServices.get(
        '/api/store-settings/',
        requireAuth: false,
      );

      final dynamic data = response.data;

      if (data is Map<String, dynamic>) {
        if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
          _storeSettings = StoreSettingsModel.fromJson(data['data']);
        } else {
          _storeSettings = StoreSettingsModel.fromJson(data);
        }
      } else if (data is List &&
          data.isNotEmpty &&
          data.first is Map<String, dynamic>) {
        _storeSettings = StoreSettingsModel.fromJson(data.first);
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
