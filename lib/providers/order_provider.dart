import 'dart:developer';
import 'dart:io';
import 'package:binetatour/core/network/error/api_error_handle.dart';
import 'package:dio/dio.dart';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:binetatour/core/network/api_services/api_services.dart';
import 'package:binetatour/data/models/order_history_model.dart';
import 'package:binetatour/data/models/order_detail_model.dart';

class OrderProvider extends ChangeNotifier {
  final ApiServices _apiServices = ApiServices();

  bool _isHistoryLoading = false;
  bool get isHistoryLoading => _isHistoryLoading;

  bool _isDetailLoading = false;
  bool get isDetailLoading => _isDetailLoading;

  bool _isLoading = false;
  bool get isLoading => _isLoading || _isHistoryLoading || _isDetailLoading;

  String? _historyErrorMessage;
  String? get historyErrorMessage => _historyErrorMessage;

  String? _detailErrorMessage;
  String? get detailErrorMessage => _detailErrorMessage;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<OrderHistoryModel> _orderHistory = [];
  List<OrderHistoryModel> get orderHistory => _orderHistory;

  Future<void> fetchOrderHistory() async {
    _isHistoryLoading = true;
    _historyErrorMessage = null;
    notifyListeners();

    try {
      final response = await _apiServices.get(
        '/api/mobile/orders/history/',
        requireAuth: true,
      );

      final dynamic raw = response.data;
      log("📦 [OrderHistory Response]: $raw");

      if (raw != null) {
        List<dynamic> list = [];
        if (raw is List) {
          list = raw;
        } else if (raw is Map) {
          if (raw['orders'] is List) {
            list = raw['orders'];
          } else if (raw['results'] is List) {
            list = raw['results'];
          } else if (raw['data'] is List) {
            list = raw['data'];
          } else if (raw['history'] is List) {
            list = raw['history'];
          }
        }

        _orderHistory = list
            .where((json) => json != null && json is Map)
            .map((json) => OrderHistoryModel.fromJson(Map<String, dynamic>.from(json as Map)))
            .toList();
      }

      _isHistoryLoading = false;
      notifyListeners();
    } catch (e) {
      _historyErrorMessage = ApiErrorHandle.sanitizeMessage(
        e.toString().replaceAll('Exception: ', ''),
        null,
      );
      log("Error fetching order history: ${e.toString()}");
      _isHistoryLoading = false;
      notifyListeners();
    }
  }

  OrderDetailModel? _orderDetail;
  OrderDetailModel? get orderDetail => _orderDetail;

  Future<void> fetchOrderDetail(String orderNumber) async {
    _isDetailLoading = true;
    _detailErrorMessage = null;
    notifyListeners();

    try {
      final response = await _apiServices.get(
        '/api/mobile/orders/$orderNumber/',
        requireAuth: true,
      );

      final dynamic raw = response.data;
      log("📦 [OrderDetail Response]: $raw");

      if (raw != null) {
        Map<String, dynamic> map = {};
        if (raw is Map<String, dynamic>) {
          if (raw['order'] is Map<String, dynamic>) {
            map = raw['order'];
          } else if (raw['data'] is Map<String, dynamic>) {
            map = raw['data'];
          } else {
            map = raw;
          }
        }
        _orderDetail = OrderDetailModel.fromJson(map);
      }

      _isDetailLoading = false;
      notifyListeners();
    } catch (e) {
      _detailErrorMessage = ApiErrorHandle.sanitizeMessage(
        e.toString().replaceAll('Exception: ', ''),
        null,
      );
      log("Error fetching order detail: ${e.toString()}");
      _isDetailLoading = false;
      notifyListeners();
    }
  }

  Future<OrderDetailModel?> getOrderDetailData(String orderNumber) async {
    try {
      final response = await _apiServices.get(
        '/api/mobile/orders/$orderNumber/',
        requireAuth: true,
      );

      final dynamic raw = response.data;
      if (raw != null) {
        Map<String, dynamic> map = {};
        if (raw is Map<String, dynamic>) {
          if (raw['order'] is Map<String, dynamic>) {
            map = raw['order'];
          } else if (raw['data'] is Map<String, dynamic>) {
            map = raw['data'];
          } else {
            map = raw;
          }
        }
        return OrderDetailModel.fromJson(map);
      }
      return null;
    } catch (e) {
      log("Error fetching order detail data: ${e.toString()}");
      return null;
    }
  }

  final Map<String, OrderDetailModel> _orderDetailsMap = {};
  Map<String, OrderDetailModel> get orderDetailsMap => _orderDetailsMap;

  final Map<String, bool> _orderLoadingMap = {};
  bool isOrderLoading(String orderNumber) =>
      _orderLoadingMap[orderNumber] ?? true;

  Future<void> fetchOrderDetailForCard(String orderNumber) async {
    if (_orderDetailsMap.containsKey(orderNumber)) return;

    _orderLoadingMap[orderNumber] = true;
    notifyListeners();

    try {
      final response = await _apiServices.get(
        '/api/mobile/orders/$orderNumber/',
        requireAuth: true,
      );

      final dynamic raw = response.data;
      if (raw != null) {
        Map<String, dynamic> map = {};
        if (raw is Map<String, dynamic>) {
          if (raw['order'] is Map<String, dynamic>) {
            map = raw['order'];
          } else if (raw['data'] is Map<String, dynamic>) {
            map = raw['data'];
          } else {
            map = raw;
          }
        }
        _orderDetailsMap[orderNumber] = OrderDetailModel.fromJson(map);
      }
    } catch (e) {
      log("Error fetching order detail data for card: ${e.toString()}");
    } finally {
      _orderLoadingMap[orderNumber] = false;
      notifyListeners();
    }
  }

  Future<int?> createOrder({
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

      log("Create order response: ${response.data}");

      // Extract the numeric order id from the response
      final int? orderId = response.data?['id'] as int?;

      if (orderId == null) {
        _isLoading = false;
        notifyListeners();
      }
      return orderId;
    } catch (e) {
      _errorMessage = e.toString();
      log("Error creating order: ${e.toString()}");
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Calls POST /api/mobile/pay/{orderId}/ with the given provider.
  /// Returns the raw response map on success, or null on failure.
  Future<Map<String, dynamic>?> payOrder({
    required int orderId,
    required String provider,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiServices.post(
        '/api/mobile/pay/$orderId/',
        data: {"provider": provider},
        requireAuth: true,
      );

      log("Pay order response: ${response.data}");
      return response.data as Map<String, dynamic>?;
    } catch (e) {
      _errorMessage = e.toString();
      log("Error paying order: ${e.toString()}");
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  final Set<String> _downloadingInvoices = {};
  bool isDownloadingInvoice(String orderId) =>
      _downloadingInvoices.contains(orderId);

  Future<String?> downloadInvoice(String orderId) async {
    _downloadingInvoices.add(orderId);
    _errorMessage = null;
    notifyListeners();

    try {
      Directory? directory;
      if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = Directory('/storage/emulated/0/Download');
        bool hasAccess = false;
        try {
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }
          final testFile = File('${directory.path}/.test_access');
          await testFile.writeAsString('test');
          await testFile.delete();
          hasAccess = true;
        } catch (e) {
          log("No access to public Download folder: $e");
          hasAccess = false;
        }

        if (!hasAccess) {
          directory = await getExternalStorageDirectory();
        }
      }

      if (directory == null) {
        throw Exception("Impossible de trouver le dossier de destination");
      }

      final savePath = '${directory.path}/Facture_$orderId.pdf';
      final dio = _apiServices.dio(true);
      await dio.download(
        '/api/orders/$orderId/invoice/',
        savePath,
        options: Options(method: 'GET'),
      );

      _downloadingInvoices.remove(orderId);
      notifyListeners();
      return savePath;
    } catch (e) {
      _errorMessage = "Erreur de téléchargement de la facture";
      log("Error downloading invoice: $e");
      _downloadingInvoices.remove(orderId);
      notifyListeners();
      return null;
    }
  }

  void clearOrders() {
    _orderHistory = [];
    _orderDetail = null;
    _errorMessage = null;
    notifyListeners();
  }
}
