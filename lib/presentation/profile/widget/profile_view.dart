import 'package:binetatour/core/login/login.dart';
import 'package:binetatour/presentation/profile/my_order/feedback/feedback_screen.dart';
import 'package:binetatour/presentation/profile/my_order/invoice/invoice_screen.dart';
import 'package:binetatour/presentation/profile/my_order/my_order_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class ProfileView extends StatelessWidget {
  final VoidCallback onLogout;
  const ProfileView({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // User Card
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 35,
                  backgroundImage: AssetImage(
                    'assets/images/dp.png',
                  ), // Replace with actual user image
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Pappu",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Pappyroy6393@Gmail.Com",
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),

          // Menu Items
          InkWell(
            onTap: () {
              // Navigate to My Orders Screen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MyOrdersPage()),
              );
            },

            child: _buildMenuItem(
              "assets/icon/order.svg",
              "Mes Commandes",
              Color(0xffF54900),
            ),
          ),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => InvoicesScreen()),
              );
            },
            child: _buildMenuItem(
              "assets/icon/invoice.svg",
              "Mes factures",
              Color(0xff00C950),
            ),
          ),
          InkWell(
            onTap: () {
              // Navigate to Feedback Screen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => GiveReviewScreen()),
              );
            },
            child: _buildMenuItem(
              "assets/icon/fav.svg",
              "Mes avis",
              Color(0xffF0B100),
            ),
          ),
          InkWell(
            onTap: () {
              // Navigate to Feedback Screen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => Login()),
              );
            },
            child: _buildMenuItem(
              "assets/icon/fav.svg",
              "Login",
              Color(0xffF0B100),
            ),
          ),

          const SizedBox(height: 20),

          // Logout Button
          GestureDetector(
            onTap: onLogout,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: const [
                  Icon(Icons.logout, color: Colors.red),
                  SizedBox(width: 15),
                  Text(
                    "Déconnexion",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
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

  Widget _buildMenuItem(String icon, String title, Color iconColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Color(0xffF5F5F5),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(25),
            ),
            child: SvgPicture.asset(icon),
          ),
          const SizedBox(width: 15),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
