import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:binetatour/core/network/error/api_error_handle.dart';
import 'package:dio/dio.dart';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:binetatour/core/token_storage/token_storage.dart';
import 'package:binetatour/core/network/api_services/api_services.dart';
import 'package:binetatour/data/models/order_history_model.dart';
import 'package:binetatour/data/models/order_detail_model.dart';
import 'package:binetatour/data/models/payment_status_model.dart';

class OrderProvider extends ChangeNotifier {
  static const String _cachedOrderHistoryKey = 'cached_order_history_data';
  final ApiServices _apiServices = ApiServices();

  bool _isHistoryLoading = false;
  bool get isHistoryLoading => _isHistoryLoading;

  bool _isHistoryLoadingMore = false;
  bool get isHistoryLoadingMore => _isHistoryLoadingMore;

  bool _historyHasMore = true;
  bool get historyHasMore => _historyHasMore;

  int _historyCurrentPage = 1;
  int get historyCurrentPage => _historyCurrentPage;

  bool _isDetailLoading = false;
  bool get isDetailLoading => _isDetailLoading;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _historyErrorMessage;
  String? get historyErrorMessage => _historyErrorMessage;

  String? _detailErrorMessage;
  String? get detailErrorMessage => _detailErrorMessage;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<OrderHistoryModel> _orderHistory = [];
  List<OrderHistoryModel> get orderHistory => _orderHistory;

  OrderProvider() {
    _init();
  }

  Future<void> _init() async {
    await _loadFromCache();
    await _fetchIfAuthenticated();
  }

  Future<void> _fetchIfAuthenticated() async {
    try {
      final token = await TokenStorage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        await fetchOrderHistory(refresh: true, showLoading: false);
      }
    } catch (e) {
      debugPrint("OrderProvider auto-fetch error: $e");
    }
  }

  Future<void> _saveToCache(dynamic rawData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (rawData != null) {
        await prefs.setString(_cachedOrderHistoryKey, json.encode(rawData));
      } else {
        await prefs.remove(_cachedOrderHistoryKey);
      }
    } catch (e) {
      debugPrint("Error saving cached order history: $e");
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString(_cachedOrderHistoryKey);
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final dynamic raw = json.decode(cachedStr);
        final parsed = _parseOrderList(raw);
        if (parsed.isNotEmpty && _orderHistory.isEmpty) {
          _orderHistory = parsed;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Error loading cached order history: $e");
    }
  }

  List<OrderHistoryModel> _parseOrderList(dynamic raw) {
    if (raw == null) return [];
    List<dynamic> list = [];
    if (raw is List) {
      list = raw;
    } else if (raw is Map) {
      if (raw['results'] is List) {
        list = raw['results'];
      } else if (raw['orders'] is List) {
        list = raw['orders'];
      } else if (raw['data'] is List) {
        list = raw['data'];
      } else if (raw['data'] is Map && raw['data']['results'] is List) {
        list = raw['data']['results'];
      } else if (raw['history'] is List) {
        list = raw['history'];
      }
    }

    return list
        .where((json) => json != null && json is Map)
        .map(
          (json) => OrderHistoryModel.fromJson(
            Map<String, dynamic>.from(json as Map),
          ),
        )
        .toList();
  }

  Future<void> fetchOrderHistory({
    bool refresh = true,
    bool showLoading = true,
  }) async {
    if (refresh) {
      _historyCurrentPage = 1;
      _historyHasMore = true;
      if (showLoading && _orderHistory.isEmpty) {
        _isHistoryLoading = true;
      }
      _historyErrorMessage = null;
      notifyListeners();
    }

    try {
      final response = await _apiServices.get(
        '/api/mobile/orders/history/',
        queryParameters: {'page': _historyCurrentPage},
        requireAuth: true,
      );

      final dynamic raw = response.data;
      final parsed = _parseOrderList(raw);

      if (raw is Map) {
        if (raw['next'] != null) {
          _historyHasMore = true;
        } else if (parsed.length < 5) {
          _historyHasMore = false;
        } else {
          _historyHasMore = true;
        }
      } else {
        _historyHasMore = parsed.length >= 5;
      }

      if (refresh) {
        _orderHistory = parsed;
        _saveToCache(raw);
      } else {
        for (final order in parsed) {
          if (!_orderHistory.any(
            (o) =>
                o.id == order.id ||
                (o.orderNumber.isNotEmpty &&
                    o.orderNumber == order.orderNumber),
          )) {
            _orderHistory.add(order);
          }
        }
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

  Future<void> fetchMoreOrderHistory() async {
    if (!_historyHasMore || _isHistoryLoadingMore || _isHistoryLoading) return;

    _isHistoryLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _historyCurrentPage + 1;
      final response = await _apiServices.get(
        '/api/mobile/orders/history/',
        queryParameters: {'page': nextPage},
        requireAuth: true,
      );

      final dynamic raw = response.data;
      final parsed = _parseOrderList(raw);

      if (parsed.isNotEmpty) {
        _historyCurrentPage = nextPage;
        for (final order in parsed) {
          if (!_orderHistory.any(
            (o) =>
                o.id == order.id ||
                (o.orderNumber.isNotEmpty &&
                    o.orderNumber == order.orderNumber),
          )) {
            _orderHistory.add(order);
          }
        }
      }

      if (raw is Map && raw['next'] == null) {
        _historyHasMore = false;
      } else if (parsed.isEmpty || parsed.length < 5) {
        _historyHasMore = false;
      }
    } catch (e) {
      log("Error fetching more order history: ${e.toString()}");
    } finally {
      _isHistoryLoadingMore = false;
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

  final Set<String> _loadingOrderNumbers = {};
  bool isOrderLoading(String orderNumber) =>
      _loadingOrderNumbers.contains(orderNumber);

  Future<void> fetchOrderDetailForCard(String orderNumber) async {
    if (_orderDetailsMap.containsKey(orderNumber) ||
        _loadingOrderNumbers.contains(orderNumber)) {
      return;
    }

    _loadingOrderNumbers.add(orderNumber);
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
      _loadingOrderNumbers.remove(orderNumber);
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

      int? orderId;
      final dynamic raw = response.data;
      if (raw is Map) {
        final rawId =
            raw['id'] ??
            (raw['order'] is Map ? raw['order']['id'] : null) ??
            (raw['data'] is Map ? raw['data']['id'] : null);
        if (rawId is num) {
          orderId = rawId.toInt();
        } else if (rawId != null) {
          orderId = int.tryParse(rawId.toString());
        }
      }
      return orderId;
    } catch (e) {
      _errorMessage = ApiErrorHandle.sanitizeMessage(
        e.toString().replaceAll('Exception: ', ''),
        null,
      );
      log("Error creating order: ${e.toString()}");
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Calls POST /api/mobile/pay/{orderId}/ with the given provider.
  /// Returns the raw response map on success, or null on failure.
  Future<Map<String, dynamic>?> payOrder({
    required int orderId,
    required String provider,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiServices.post(
        '/api/mobile/pay/$orderId/',
        data: {"provider": provider},
        requireAuth: true,
      );

      log("Pay order response: ${response.data}");
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return null;
    } catch (e) {
      _errorMessage = ApiErrorHandle.sanitizeMessage(
        e.toString().replaceAll('Exception: ', ''),
        null,
      );
      log("Error paying order: ${e.toString()}");
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  PaymentStatusModel? _paymentStatus;
  PaymentStatusModel? get paymentStatus => _paymentStatus;

  bool _isCheckingPaymentStatus = false;
  bool get isCheckingPaymentStatus => _isCheckingPaymentStatus;

  String? _paymentStatusError;
  String? get paymentStatusError => _paymentStatusError;

  /// Calls GET /api/mobile/pay/{transaction_id}/status/ to check the status of a payment.
  Future<PaymentStatusModel?> checkPaymentStatus(int transactionId) async {
    _isCheckingPaymentStatus = true;
    _paymentStatusError = null;
    notifyListeners();

    try {
      final response = await _apiServices.get(
        '/api/mobile/pay/$transactionId/status/',
        requireAuth: true,
      );

      log("🔍 [PaymentStatus Response]: ${response.data}");

      if (response.data != null && response.data is Map<String, dynamic>) {
        _paymentStatus = PaymentStatusModel.fromJson(
          response.data as Map<String, dynamic>,
        );
      } else if (response.data != null && response.data is Map) {
        _paymentStatus = PaymentStatusModel.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
      return _paymentStatus;
    } catch (e) {
      _paymentStatusError = e.toString();
      log("Error checking payment status: ${e.toString()}");
      return null;
    } finally {
      _isCheckingPaymentStatus = false;
      notifyListeners();
    }
  }

  void clearPaymentStatus() {
    _paymentStatus = null;
    _paymentStatusError = null;
    _isCheckingPaymentStatus = false;
    notifyListeners();
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
    _saveToCache(null);
    notifyListeners();
  }
}
