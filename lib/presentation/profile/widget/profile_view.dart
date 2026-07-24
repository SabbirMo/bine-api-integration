import 'package:binetatour/core/token_storage/token_storage.dart';
import 'package:binetatour/presentation/profile/my_order/feedback/feedback_screen.dart';
import 'package:binetatour/presentation/profile/my_order/invoice/invoice_screen.dart';
import 'package:binetatour/presentation/profile/my_order/my_order_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class ProfileView extends StatefulWidget {
  final VoidCallback onLogout;
  const ProfileView({super.key, required this.onLogout});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  String name = "Loading...";
  String email = "Loading...";
  String? profileImage;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final storedName = await TokenStorage.getName();
    final storedEmail = await TokenStorage.getEmail();
    final storedImage = await TokenStorage.getProfileImage();

    setState(() {
      name = (storedName == null || storedName == "null" || storedName.isEmpty)
          ? "Utilisateur"
          : storedName;
      email = (storedEmail == null || storedEmail == "null") ? "" : storedEmail;
      profileImage = (storedImage == "null") ? null : storedImage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
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
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: user?.photoURL != null
                      ? NetworkImage(user!.photoURL!)
                      : profileImage != null
                      ? NetworkImage(profileImage!)
                      : const AssetImage("assets/images/dp.png")
                            as ImageProvider,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      Text(
                        user?.email ?? email,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
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
              const Color(0xffF54900),
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
              const Color(0xff00C950),
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
              const Color(0xffF0B100),
            ),
          ),
          const SizedBox(height: 20),

          // Logout Button
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text("Déconnexion"),
                    content: const Text(
                      "Êtes-vous sûr de vouloir vous déconnecter ?",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          "Annuler",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onLogout();
                        },
                        child: const Text(
                          "Se déconnecter",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
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
