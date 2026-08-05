import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/order_provider.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().fetchOrderHistory();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Mes factures",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: "Recherche de facture...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF1F1F1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, child) {
          if (orderProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6900)),
            );
          }

          if (orderProvider.errorMessage != null) {
            return Center(child: Text("Erreur: ${orderProvider.errorMessage}"));
          }

          final allOrders = orderProvider.orderHistory;

          final displayOrders = allOrders.where((order) {
            final statusStr = order.status.toLowerCase();
            final matchesStatus = statusStr != 'cancelled';
            final numStr = order.orderNumber.isNotEmpty
                ? order.orderNumber
                : "ORD-${order.id}";
            final matchesSearch = numStr
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());
            return matchesStatus && matchesSearch;
          }).toList();

          if (displayOrders.isEmpty) {
            return const Center(child: Text("Aucune facture trouvée."));
          }

          return RefreshIndicator(
            color: const Color(0xFFFF6900),
            onRefresh: () async {
              await context.read<OrderProvider>().fetchOrderHistory();
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: displayOrders.length,
              itemBuilder: (context, index) {
                final order = displayOrders[index];

                final statusStr = order.status.toLowerCase();
                String statusText = "En cours";
                Color statusColor = const Color(0xFFFDEBD0);
                Color textColor = const Color(0xFFD35400);
                bool isDone = false;

                if (statusStr == 'delivered') {
                  statusText = "Livrée";
                  statusColor = const Color(0xFF28B446);
                  textColor = Colors.white;
                  isDone = true;
                }

                final displayOrderNum = order.orderNumber.isNotEmpty
                    ? order.orderNumber
                    : "ORD-${order.id}";

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildInvoiceCard(
                    context,
                    displayId: displayOrderNum,
                    orderId: order.id.toString(),
                    date: order.createdAt,
                    total: "${order.totalAmount} FCFA",
                    status: statusText,
                    statusColor: statusColor,
                    textColor: textColor,
                    isDone: isDone,
                    isDownloading: orderProvider.isDownloadingInvoice(
                      order.id.toString(),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildInvoiceCard(
    BuildContext context, {
    required String displayId,
    required String orderId,
    required String date,
    required String total,
    required String status,
    required Color statusColor,
    Color textColor = Colors.white,
    required bool isDone,
    required bool isDownloading,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                displayId,
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
                  color: statusColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(date, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Total à payer",
                style: TextStyle(color: Colors.blueGrey, fontSize: 14),
              ),
              Text(
                total,
                style: const TextStyle(
                  color: Color(0xFFE65100),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: isDownloading
                  ? () {}
                  : () async {
                      final path = await context
                          .read<OrderProvider>()
                          .downloadInvoice(orderId);
                      if (context.mounted) {
                        if (path != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "Facture téléchargée avec succès !\nEmplacement : $path",
                              ),
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        } else {
                          final errorMsg =
                              context.read<OrderProvider>().errorMessage ??
                              "Erreur lors du téléchargement";
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(errorMsg)));
                        }
                      }
                    },
              icon: isDownloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.download, size: 20),
              label: Text(
                isDownloading
                    ? "Téléchargement..."
                    : "Télécharger La Facture (PDF)",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
