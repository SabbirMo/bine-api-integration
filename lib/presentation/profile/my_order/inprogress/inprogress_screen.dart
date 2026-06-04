import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class InprogressScreen extends StatelessWidget {
  final String status;
  const InprogressScreen({super.key, required this.status});

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
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildOrderHeader(status),
            const SizedBox(height: 16),
            status == "annulees"
                ? _buildCancelledTracking()
                : status == "livrees"
                ? _buildDeliveredTracking()
                : _buildInprogressTracking(),
            const SizedBox(height: 16),
            _buildOrderedItems(),
            const SizedBox(height: 16),
            _buildDeliveryInfo(),
            const SizedBox(height: 16),
            _buildPaymentInfo(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInprogressTracking() {
    return _sectionCard(
      title: "Suivi De Livraison",
      child: Column(
        children: [
          // Step 1: Preparation - Completed (Green Check)
          _trackingStep(
            title: "En Préparation",
            subtitle: "Nous préparons votre commande",
            date: "15 Avril 2026, 14:30",
            isCancelled: false,
            isDone: true,
            hasNext: true,
            icon: Icons.check, // Matches image_015f4d.png
          ),
          // Step 2: Shipping - Completed (Green Truck/Car)
          _trackingStep(
            title: "Expédiée",
            subtitle: "Votre commande est en route",
            date: "15 Avril 2026, 14:30",
            isCancelled: false,
            isDone: true,
            hasNext: true,
            icon: Icons
                .local_shipping, // Replaces check with the car icon from your image
          ),
          // Step 3: Delivered - Pending (Grey Location)
          _trackingStep(
            title: "Livrée",
            subtitle: "Commande livrée avec succès",
            date: "",
            isCancelled: false,
            isDone: false, // Remains grey
            hasNext: false,
            icon: Icons
                .location_on_outlined, // Uses the location icon from your image
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveredTracking() {
    return _sectionCard(
      title: "Suivi De Livraison",
      child: Column(
        children: [
          // Step 1: Preparation - Completed
          _trackingStep(
            title: "En Préparation",
            subtitle: "Nous préparons votre commande",
            date: "15 Avril 2026, 14:30",
            isDone: true,
            icon: Icons.check,
            isCancelled: false,
            hasNext: true,
          ),
          // Step 2: Shipping - Completed (Shows Green Car)
          _trackingStep(
            title: "Expédiée",
            subtitle: "Votre commande est en route",
            date: "16 Avril 2026, 09:00",
            isDone: true,
            hasNext: true,
            icon: Icons.check,
            isCancelled: false,
          ),
          // Step 3: Delivered - Completed (Shows Green Location)
          _trackingStep(
            title: "Livrée",
            subtitle: "Commande livrée avec succès",
            date: "",
            isDone: true,
            hasNext: false,
            icon: Icons.check,
            isCancelled: false,
          ),
        ],
      ),
    );
  }

  // 1. Orange Header with Order ID and Clock
  Widget _buildOrderHeader(String status) {
    return Container(
      padding: EdgeInsets.all(20),
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
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "CMD-001",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "Date de commande",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                "15 Avril 2026",
                style: TextStyle(
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

  // 2. Vertical Delivery Tracking Timeline

  // 3. Ordered Items Section
  Widget _buildOrderedItems() {
    return _sectionCard(
      title: "Articles commandés (2 articles)",
      child: Column(
        children: [
          _itemRow("assets/images/lounge.jpg", "Coffee", "20 000 FCFA"),
          const Divider(height: 24),
          _itemRow("assets/images/laptop.jpg", "Laptop Pro", "125 000 FCFA"),
        ],
      ),
    );
  }

  // 4. Delivery Info Section
  Widget _buildDeliveryInfo() {
    return _sectionCard(
      title: "Informations de livraison",
      child: Column(
        children: [
          _infoRow(
            Icons.phone_outlined,
            "Contact",
            "+221 77 123 45 67\n+221 77 987 65 43",
          ),
          const SizedBox(height: 16),
          _infoRow(
            Icons.location_on_outlined,
            "Adresse de livraison",
            "Sicap Mermoz, Villa 123, près de la pharmacie centrale, Dakar",
          ),
          const SizedBox(height: 16),
          _infoRow(
            Icons.calendar_today_outlined,
            "Date de livraison prévue",
            "18 Avril 2026",
          ),
          const SizedBox(height: 16),
          _infoRow(
            Icons.access_time_outlined,
            "Heure de livraison",
            "14:00 - 16:00",
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1EB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Note spéciale",
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
                Text(
                  "Sonner à la porte principale",
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 5. Payment Info Section
  Widget _buildPaymentInfo() {
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
                Image.asset("assets/images/money.png", height: 25, width: 25),
                const SizedBox(width: 12),
                const Text(
                  "Orange Money",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    "Payé",
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _priceRow("Sous-total", "120,000 FCFA"),
          const SizedBox(height: 8),
          _priceRow("Frais de livraison", "5,000 FCFA"),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Total payé",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Text(
                "125,000 FCFA",
                style: TextStyle(
                  color: Color(0xFFFF6900),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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

  // Helper Widgets
  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
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

  // Helper to return specific icons for each step when NOT done
  Widget _getStepIcon(int index) {
    Color iconColor = Colors.grey.shade600;
    switch (index) {
      case 0: // Preparation
        return Icon(Icons.inventory_2_outlined, size: 16, color: iconColor);
      case 1: // Shipping (Car/Truck)
        return Icon(Icons.local_shipping_outlined, size: 16, color: iconColor);
      case 2: // Delivery (Location)
        return Icon(Icons.location_on_outlined, size: 16, color: iconColor);
      default:
        return Icon(Icons.circle, size: 8, color: iconColor);
    }
  }

  Widget _itemRow(String img, String title, String price) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Colors.grey[100],
            image: DecorationImage(image: AssetImage(img), fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                price,
                style: const TextStyle(
                  color: Color(0xFFFF6900),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const Text(
                "Livraison: 10 000",
                style: TextStyle(color: Colors.grey, fontSize: 10),
              ),
              const Row(
                children: [
                  Icon(Icons.circle, size: 8, color: Colors.red),
                  SizedBox(width: 4),
                  Text(
                    "Rouge  Taille: 2m  Qté: 1",
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
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

  Widget _buildCancelledTracking() {
    return _sectionCard(
      title: "Suivi De Livraison",
      child: Column(
        children: [
          // Completed first step (shown in red to match the cancellation theme)
          _trackingStep(
            title: "En Préparation",
            subtitle: "Nous préparons votre commande",
            date: "15 Avril 2026, 14:30",
            isCancelled: false, // This step itself isn't the cancellation
            isDone: true,
            hasNext: true,
            icon: Icons.check,
          ),
          // Final Cancellation step
          _trackingStep(
            title: "Annulée",
            subtitle: "Annulée à la demande du client",
            date: "",
            isCancelled: true,
            isDone: true,
            hasNext: false,
            icon: Icons.close,
          ),
        ],
      ),
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
    // Use Red for cancellation or Grey for pending
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
