import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:binetatour/core/network/api_services/api_services.dart';
import 'package:binetatour/data/models/order_history_model.dart';

class OrderProvider extends ChangeNotifier {
  final ApiServices _apiServices = ApiServices();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<OrderHistoryModel> _orderHistory = [];
  List<OrderHistoryModel> get orderHistory => _orderHistory;

  Future<void> fetchOrderHistory() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiServices.get(
        '/api/mobile/orders/history/',
        requireAuth: true,
      );

      if (response.data != null) {
        final List<dynamic> data = response.data;
        _orderHistory = data.map((json) => OrderHistoryModel.fromJson(json)).toList();
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      log("Error fetching order history: ${e.toString()}");
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createOrder({
    required List<Map<String, dynamic>> items,
    required String customerName,
    required String customerSurname,
    required String customerPhone,
    required String customerPhone2,
    required String customerAddress,
    required String deliveryDate,
    required String deliveryTime,
    required String deliveryTimeEnd,
    required String deliveryNote,
    required String deliveryFee,
    required String paymentMethod,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = {
        "items": items,
        "customer_name": customerName,
        "customer_surname": customerSurname,
        "customer_phone": customerPhone,
        "customer_phone2": customerPhone2,
        "customer_address": customerAddress,
        "delivery_date": deliveryDate,
        "delivery_time": deliveryTime,
        "delivery_time_end": deliveryTimeEnd,
        "delivery_note": deliveryNote,
        "delivery_fee": deliveryFee,
        "payment_method": paymentMethod,
      };

      final response = await _apiServices.post(
        '/api/mobile/orders/',
        data: data,
        requireAuth: true,
      );

      log("Response: ${response.data}");

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      log("Error: ${e.toString()}");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
