import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:binetatour/core/network/api_services/api_services.dart';

class FeedbackProvider extends ChangeNotifier {
  final ApiServices _apiServices = ApiServices();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  List<XFile> selectedImages = [];

  Future<void> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        selectedImages.add(image);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  void removeImage(int index) {
    if (index >= 0 && index < selectedImages.length) {
      selectedImages.removeAt(index);
      notifyListeners();
    }
  }

  void clearImages() {
    selectedImages.clear();
    notifyListeners();
  }

  Future<bool> submitFeedback({
    required String orderNumber,
    required double rating,
    required String comment,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final formData = FormData.fromMap({
        'rating': rating.toInt(),
        'comment': comment,
      });

      for (var file in selectedImages) {
        formData.files.add(
          MapEntry('media', await MultipartFile.fromFile(file.path)),
        );
      }

      await _apiServices.post(
        '/api/mobile/orders/$orderNumber/review/',
        data: formData,
        requireAuth: true,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      log("Error submitting feedback: ${e.toString()}");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
