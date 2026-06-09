import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/order_provider.dart';
import 'package:binetatour/data/models/order_detail_model.dart';
import 'package:binetatour/presentation/profile/my_order/feedback/feedback_details_screen.dart';

class OrderItemsScreen extends StatefulWidget {
  final String orderNumber;
  final String createdAt;

  const OrderItemsScreen({
    super.key,
    required this.orderNumber,
    required this.createdAt,
  });

  @override
  State<OrderItemsScreen> createState() => _OrderItemsScreenState();
}

class _OrderItemsScreenState extends State<OrderItemsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().fetchOrderDetailForCard(widget.orderNumber);
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
        title: Text(
          widget.orderNumber,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<OrderProvider>(
        builder: (context, provider, child) {
          final isLoading = provider.isOrderLoading(widget.orderNumber);
          final detail = provider.orderDetailsMap[widget.orderNumber];
          final items = detail?.items;

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
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Container(
                    width: double.infinity,
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
                    child: isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFF6900),
                            ),
                          )
                        : (items != null && items.isNotEmpty)
                        ? ListView.builder(
                            shrinkWrap: true,
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: _buildItemCard(
                                  context,
                                  item,
                                  widget.orderNumber,
                                  widget.createdAt,
                                ),
                              );
                            },
                          )
                        : const Text("Aucun article trouvé."),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildItemCard(
    BuildContext context,
    OrderItemModel item,
    String orderNumber,
    String createdAt,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FeedbackDetailsScreen(
                          orderId: orderNumber,
                          date: createdAt,
                          item: item,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBE4D8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          "Donner Un Avis",
                          style: TextStyle(
                            color: Color(0xFFE65100),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Color(0xFFE65100),
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
