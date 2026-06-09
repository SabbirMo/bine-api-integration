import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/order_provider.dart';
import 'package:binetatour/data/models/order_detail_model.dart';
import 'package:binetatour/presentation/profile/my_order/feedback/order_items_screen.dart';

class InprogressScreen extends StatefulWidget {
  final String status;
  final String orderNumber;
  const InprogressScreen({
    super.key,
    required this.status,
    required this.orderNumber,
  });

  @override
  State<InprogressScreen> createState() => _InprogressScreenState();
}

class _InprogressScreenState extends State<InprogressScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().fetchOrderDetail(widget.orderNumber);
    });
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
          "Détails de la commande",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
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
          final orderDetail = provider.orderDetail;
          if (orderDetail == null) {
            return const Center(child: Text("Commande introuvable"));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildOrderHeader(widget.status, orderDetail),
                const SizedBox(height: 16),
                _buildTracking(orderDetail),
                const SizedBox(height: 16),
                _buildOrderedItems(orderDetail),
                const SizedBox(height: 16),
                _buildDeliveryInfo(orderDetail),
                const SizedBox(height: 16),
                _buildPaymentInfo(orderDetail),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderHeader(String status, OrderDetailModel orderDetail) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: status == "enCours"
            ? const LinearGradient(
                colors: [Color(0xFFE74B08), Color(0xFFFD8C2C)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : status == "livrees"
            ? const LinearGradient(
                colors: [Color(0xFF28A745), Color(0xFF71C671)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFFB313A), Color(0xFFFB313A)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                orderDetail.orderNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Date de commande",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                orderDetail.createdAt,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          status == "enCours"
              ? SvgPicture.asset("assets/icon/clock #.svg")
              : status == "livrees"
              ? SvgPicture.asset("assets/icon/deliverydone.svg")
              : SvgPicture.asset("assets/icon/cancelled.svg"),
        ],
      ),
    );
  }

  Widget _buildTracking(OrderDetailModel orderDetail) {
    return _sectionCard(
      title: "Suivi De Livraison",
      child: Column(
        children: List.generate(orderDetail.trackingSteps.length, (index) {
          final step = orderDetail.trackingSteps[index];
          final isDone = step.state == "active" || step.state == "completed";
          final isCancelled = step.state == "cancelled";
          final hasNext = index < orderDetail.trackingSteps.length - 1;

          IconData icon;
          if (isCancelled) {
            icon = Icons.close;
          } else if (isDone) {
            icon = Icons.check;
          } else {
            icon = _getStepIcon(index);
          }

          String formattedDate = "";
          if (step.timestamp != null && step.timestamp!.isNotEmpty) {
            try {
              final date = DateTime.parse(step.timestamp!);
              formattedDate =
                  "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
            } catch (e) {
              formattedDate = step.timestamp!;
            }
          }

          return _trackingStep(
            title: step.label,
            subtitle: step.description,
            date: formattedDate,
            isCancelled: isCancelled,
            isDone: isDone,
            hasNext: hasNext,
            icon: icon,
          );
        }),
      ),
    );
  }

  Widget _buildOrderedItems(OrderDetailModel orderDetail) {
    return _sectionCard(
      title:
          "Articles commandés (${orderDetail.items.length} article${orderDetail.items.length > 1 ? 's' : ''})",
      child: Column(
        children: orderDetail.items.map((item) {
          return Column(
            children: [
              _itemRow(item),
              if (item != orderDetail.items.last) const Divider(height: 24),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDeliveryInfo(OrderDetailModel orderDetail) {
    return _sectionCard(
      title: "Informations de livraison",
      child: Column(
        children: [
          _infoRow(
            Icons.phone_outlined,
            "Contact",
            orderDetail.customerPhone +
                (orderDetail.customerPhone2.isNotEmpty
                    ? "\n${orderDetail.customerPhone2}"
                    : ""),
          ),
          const SizedBox(height: 16),
          _infoRow(
            Icons.location_on_outlined,
            "Adresse de livraison",
            orderDetail.customerAddress,
          ),
          const SizedBox(height: 16),
          _infoRow(
            Icons.calendar_today_outlined,
            "Date de livraison prévue",
            orderDetail.deliveryDate,
          ),
          const SizedBox(height: 16),
          _infoRow(
            Icons.access_time_outlined,
            "Heure de livraison",
            "${orderDetail.deliveryTime} - ${orderDetail.deliveryTimeEnd}",
          ),
          if (orderDetail.deliveryNote.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1EB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Note spéciale",
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  Text(
                    orderDetail.deliveryNote,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentInfo(OrderDetailModel orderDetail) {
    String paymentImage = "assets/images/money.png";
    final method = orderDetail.paymentMethod.toLowerCase();
    if (method.contains("wave")) {
      paymentImage = "assets/images/wave.png";
    } else if (method.contains("cash") ||
        method.contains("liquide") ||
        method.contains("case") ||
        method.contains("delivery")) {
      paymentImage = "assets/images/truck.png";
    } else {
      paymentImage = "assets/images/money.png";
    }

    return _sectionCard(
      title: "Informations de paiement",
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Image.asset(
                  paymentImage,
                  height: 25,
                  width: 25,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.payment, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Text(
                  orderDetail.paymentMethod.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: orderDetail.paymentStatus.toLowerCase() == "paid"
                        ? Colors.green[50]
                        : Colors.orange[50],
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    orderDetail.paymentStatus.toUpperCase(),
                    style: TextStyle(
                      color: orderDetail.paymentStatus.toLowerCase() == "paid"
                          ? Colors.green
                          : Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _priceRow("Sous-total", "${orderDetail.subtotalAmount} FCFA"),
          const SizedBox(height: 8),
          _priceRow("Frais de livraison", "${orderDetail.deliveryFee} FCFA"),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Total payé",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                "${orderDetail.totalAmount} FCFA",
                style: const TextStyle(
                  color: Color(0xFFFF6900),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.status == 'livrees')
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderItemsScreen(
                            orderNumber: orderDetail.orderNumber,
                            createdAt: orderDetail.createdAt,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.star_border, size: 20),
                    label: const Text("Votre avis"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEAA61F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.file_download_outlined, size: 20),
                    label: const Text("Facture"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD44C23),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.file_download_outlined, size: 20),
                label: const Text("Facture"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6900),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
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
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  IconData _getStepIcon(int index) {
    switch (index) {
      case 0:
        return Icons.inventory_2_outlined;
      case 1:
        return Icons.local_shipping_outlined;
      case 2:
        return Icons.location_on_outlined;
      default:
        return Icons.circle;
    }
  }

  Widget _itemRow(OrderItemModel item) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Colors.grey[100],
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
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                "${item.unitPrice} FCFA",
                style: const TextStyle(
                  color: Color(0xFFFF6900),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: _hexToColor(item.colorCode),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      "${item.colorName}  Taille: ${item.size}  Qté: ${item.quantity}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _hexToColor(String hexString) {
    if (hexString.isEmpty) return Colors.transparent;
    try {
      var hexColor = hexString.replaceAll("#", "");
      if (hexColor.length == 6) {
        hexColor = "FF$hexColor";
      }
      return Color(int.parse("0x$hexColor"));
    } catch (e) {
      return Colors.transparent;
    }
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.blueGrey[300]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _priceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ],
    );
  }

  Widget _trackingStep({
    required String title,
    required String subtitle,
    required String date,
    required bool isCancelled,
    required bool isDone,
    required bool hasNext,
    required IconData icon,
  }) {
    final Color statusColor = isCancelled
        ? const Color(0xFFFF3D00)
        : (isDone ? const Color(0xFF0EB205) : Colors.grey.shade300);

    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              if (hasNext)
                Expanded(
                  child: CustomPaint(
                    size: const Size(1, double.infinity),
                    painter: DashedLinePainter(
                      color: statusColor.withValues(alpha: 0.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (date.isNotEmpty)
                        Text(
                          date,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DashedLinePainter extends CustomPainter {
  final Color color;
  DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    double dashHeight = 4, dashSpace = 3, startY = 5;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    while (startY < size.height - 5) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
