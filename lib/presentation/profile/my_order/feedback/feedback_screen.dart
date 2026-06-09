import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/presentation/profile/my_order/feedback/order_items_screen.dart';
import 'package:binetatour/providers/order_provider.dart';
import 'package:binetatour/data/models/order_history_model.dart';
import 'package:binetatour/data/models/order_detail_model.dart';

class GiveReviewScreen extends StatefulWidget {
  const GiveReviewScreen({super.key});

  @override
  State<GiveReviewScreen> createState() => _GiveReviewScreenState();
}

class _GiveReviewScreenState extends State<GiveReviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().fetchOrderHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Je donne mon avis",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<OrderProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6900)),
            );
          }

          if (provider.errorMessage != null) {
            return Center(child: Text("Erreur: ${provider.errorMessage}"));
          }

          final deliveredOrders = provider.orderHistory
              .where(
                (o) =>
                    o.status.toLowerCase() == 'delivered' ||
                    o.status.toLowerCase() == 'livrees',
              )
              .toList();

          if (deliveredOrders.isEmpty) {
            return const Center(
              child: Text(
                "Aucune commande livrée.",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  "Sélectionnez une commande livrée pour laisser un avis.",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: deliveredOrders.length,
                  itemBuilder: (context, index) {
                    final order = deliveredOrders[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrderItemsScreen(
                                orderNumber: order.orderNumber,
                                createdAt: order.createdAt,
                              ),
                            ),
                          );
                        },
                        child: OrderReviewCard(order: order),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class OrderReviewCard extends StatefulWidget {
  final OrderHistoryModel order;

  const OrderReviewCard({super.key, required this.order});

  @override
  State<OrderReviewCard> createState() => _OrderReviewCardState();
}

class _OrderReviewCardState extends State<OrderReviewCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().fetchOrderDetailForCard(
        widget.order.orderNumber,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, provider, child) {
        final isLoading = provider.isOrderLoading(widget.order.orderNumber);
        final detail = provider.orderDetailsMap[widget.order.orderNumber];
        final items = detail?.items;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Commande ${widget.order.orderNumber}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF28B446), // Success Green
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "Livrée",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Livrée le ${widget.order.createdAt}",
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFE65100),
                      ),
                    ),
                  ),
                )
              else if (items != null && items.isNotEmpty)
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: _itemRowWithImage(item),
                  ),
                )
              else
                ...widget.order.productNames.map(
                  (name) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: _itemRow(name),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderItemsScreen(
                          orderNumber: widget.order.orderNumber,
                          createdAt: widget.order.createdAt,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.star_border, size: 20),
                  label: const Text(
                    "Donner des avis",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFBE4D8), // Soft Orange
                    foregroundColor: const Color(
                      0xFFE65100,
                    ), // Dark Orange Text/Icon
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _itemRowWithImage(OrderItemModel item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[200],
              image: DecorationImage(
                image: NetworkImage(item.mainImage),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.productName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemRow(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }
}
