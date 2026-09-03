import 'dart:developer';

import 'package:binetatour/presentation/profile/my_order/inprogress/inprogress_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/order_provider.dart';
import 'package:binetatour/data/models/order_history_model.dart';
import 'package:binetatour/core/widgets/shimmer/cool_shimmer_kit.dart';
import 'package:binetatour/core/utils/date_utils.dart';
import 'package:binetatour/core/utils/price_utils.dart';

enum OrderStatus { enCours, livrees, annulees }

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  OrderStatus _selectedStatus = OrderStatus.enCours;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<OrderProvider>();
      provider.fetchOrderHistory(
        refresh: true,
        showLoading: provider.orderHistory.isEmpty,
      );
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final provider = context.read<OrderProvider>();
      if (provider.historyHasMore &&
          !provider.isHistoryLoadingMore &&
          !provider.isHistoryLoading) {
        provider.fetchMoreOrderHistory();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Mes Commandes",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          _buildTabSwitcher(),
          const SizedBox(height: 20),
          Expanded(child: _buildOrderList()),
        ],
      ),
    );
  }

  // 1. Tab Switcher Widget
  Widget _buildTabSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _tabItem(
            "En cours",
            "assets/images/truckv.png",
            OrderStatus.enCours,
            const Color(0xFFFF6900),
            isSVG: false,
          ),
          _tabItem(
            "Livrées",
            "assets/icon/locationv.svg",
            OrderStatus.livrees,
            const Color(0xFF00C853),
          ),
          _tabItem(
            "Annulées",
            "assets/icon/cancelv.svg",
            OrderStatus.annulees,
            const Color(0xFFFB313A),
          ),
        ],
      ),
    );
  }

  Widget _tabItem(
    String label,
    String icon,
    OrderStatus status,
    Color activeColor, {
    bool isSVG = true,
  }) {
    bool isSelected = _selectedStatus == status;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedStatus = status);
        log(_selectedStatus.name);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade300,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            isSVG
                ? (icon.contains('cancelv.svg')
                      ? Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : activeColor,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.close,
                            size: 11,
                            color: isSelected ? activeColor : Colors.white,
                          ),
                        )
                      : SvgPicture.asset(
                          icon,
                          width: 16,
                          height: 16,
                          colorFilter: ColorFilter.mode(
                            isSelected ? Colors.white : activeColor,
                            BlendMode.srcIn,
                          ),
                        ))
                : Image.asset(icon, width: 16, height: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2. Order List
  Widget _buildOrderList() {
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, child) {
        if (orderProvider.isHistoryLoading &&
            orderProvider.orderHistory.isEmpty) {
          return const ShimmerList.orders(itemCount: 5);
        }

        if (orderProvider.historyErrorMessage != null &&
            orderProvider.orderHistory.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xFFFF6900),
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Erreur: ${orderProvider.historyErrorMessage}",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<OrderProvider>().fetchOrderHistory();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6900),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Réessayer"),
                  ),
                ],
              ),
            ),
          );
        }

        // Filter logic
        final List<OrderHistoryModel> allOrders = orderProvider.orderHistory;
        final List<OrderHistoryModel> filteredOrders = allOrders.where((order) {
          final statusStr = order.status.toLowerCase();
          switch (_selectedStatus) {
            case OrderStatus.enCours:
              return statusStr != 'delivered' && statusStr != 'cancelled';
            case OrderStatus.livrees:
              return statusStr == 'delivered';
            case OrderStatus.annulees:
              return statusStr == 'cancelled';
          }
        }).toList();

        if (filteredOrders.isEmpty) {
          return RefreshIndicator(
            color: const Color(0xFFFF6900),
            onRefresh: () async {
              try {
                await context.read<OrderProvider>().fetchOrderHistory().timeout(
                  const Duration(seconds: 8),
                );
              } catch (e) {
                debugPrint("Order history refresh error or timeout: $e");
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 160),
                Center(child: Text("Aucune commande trouvée.")),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: const Color(0xFFFF6900),
          onRefresh: () async {
            try {
              await context.read<OrderProvider>().fetchOrderHistory().timeout(
                const Duration(seconds: 8),
              );
            } catch (e) {
              debugPrint("Order history refresh error or timeout: $e");
            }
          },
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filteredOrders.length +
                (orderProvider.isHistoryLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == filteredOrders.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: CoolShimmer(
                      child: CoolShimmerBone.pill(width: 80, height: 18),
                    ),
                  ),
                );
              }
              final order = filteredOrders[index];
              final targetOrderNum = order.orderNumber.isNotEmpty
                  ? order.orderNumber
                  : order.id.toString();
              return _orderCard(
                id: targetOrderNum,
                date: AppDateUtils.formatDate(order.createdAt),
                items: "${order.itemCount} article(s)",
                price: AppPriceUtils.formatPrice(order.totalAmount),
                productNames: order.productNames.join(", "),
                status: _selectedStatus,
              );
            },
          ),
        );
      },
    );
  }

  // 3. The Order Card
  Widget _orderCard({
    required String id,
    required String date,
    required String items,
    required String price,
    required String productNames,
    required OrderStatus status,
  }) {
    Color themeColor;
    Color bgColor;
    String statusText;

    switch (status) {
      case OrderStatus.livrees:
        themeColor = const Color(0xFF00C853);
        bgColor = const Color(0xFFE8F5E9);
        statusText = "Livrées";
        break;
      case OrderStatus.annulees:
        themeColor = const Color(0xFFFF3D00);
        bgColor = const Color(0xFFFFEBEE);
        statusText = "Annulées";
        break;
      default:
        themeColor = const Color(0xFFFF6900);
        bgColor = Colors.white;
        statusText = "En cours";
    }

    return InkWell(
      onTap: () {
        log(_selectedStatus.name);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                InprogressScreen(status: _selectedStatus.name, orderNumber: id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Color(0xFFEBEBEB)),
          boxShadow: [
            BoxShadow(
              color: Color(0x19000000),
              blurRadius: 23.44,
              offset: Offset(0, 10.74),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      id,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      items,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(width: 10),
                    _statusBadge(statusText, themeColor, Colors.white),
                  ],
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              date,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              productNames.isEmpty ? "Aucun produit" : productNames,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Text(
              price,
              style: TextStyle(
                color: themeColor,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String text, Color color, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
