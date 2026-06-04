import 'package:binetatour/presentation/profile/my_order/inprogress/inprogress_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

enum OrderStatus { enCours, livrees, annulees }

OrderStatus _selectedStatus = OrderStatus.enCours;

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  OrderStatus _selectedStatus = OrderStatus.enCours;

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
            const Color(0xFFFF3D00),
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
        print(_selectedStatus.name);
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
                    color: activeColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            isSVG
                ? SvgPicture.asset(
                    icon,
                    width: 16,
                    height: 16,
                    color: isSelected ? Colors.white : activeColor,
                  )
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
    // Filter logic would go here based on _selectedStatus
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 2, // Example count
      itemBuilder: (context, index) {
        return _orderCard(
          id: "CMD-001",
          date: "15 Avril 2026",
          items: index == 0 ? "2 articles" : "1 article",
          price: "125,000 FCFA",
          status: _selectedStatus,
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
    required OrderStatus status,
  }) {
    Color themeColor;
    Color bgColor;
    String statusText;
    Color textColor;

    switch (status) {
      case OrderStatus.livrees:
        themeColor = const Color(0xFF00C853);
        bgColor = const Color(0xFFE8F5E9);
        statusText = "Livrées";
        textColor = Colors.white;
        break;
      case OrderStatus.annulees:
        themeColor = const Color(0xFFFF3D00);
        bgColor = const Color(0xFFFFEBEE);
        statusText = "Annulées";
        textColor = Colors.white;
        break;
      default:
        themeColor = const Color(0xFFFF6900);
        bgColor = Colors.white;
        statusText = "En cours";  
        textColor = Color(0xffCA3500);
    }

    return InkWell(
      onTap: (){
        print(_selectedStatus.name);
        Navigator.push(context, MaterialPageRoute(builder: (_) => InprogressScreen(status: _selectedStatus.name,)));
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
                const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 8),
            Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            const Text(
              "Coffee Fort Blend   Coffee Fort Blend",
              style: TextStyle(color: Colors.grey, fontSize: 12),
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
