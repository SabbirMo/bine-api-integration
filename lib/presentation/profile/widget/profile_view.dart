import 'package:binetatour/core/login/login_provider.dart';
import 'package:binetatour/core/token_storage/token_storage.dart';
import 'package:binetatour/presentation/profile/my_order/feedback/feedback_screen.dart';
import 'package:binetatour/presentation/profile/my_order/invoice/invoice_screen.dart';
import 'package:binetatour/presentation/profile/my_order/my_order_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

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
      profileImage =
          (storedImage == "null" || storedImage == null || storedImage.isEmpty)
          ? null
          : storedImage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userPhotoUrl = user?.photoURL;
    final localProfileImage = profileImage;
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
                ClipOval(
                  child: Container(
                    width: 70,
                    height: 70,
                    color: Colors.grey[200],
                    child: (userPhotoUrl != null && userPhotoUrl.isNotEmpty)
                        ? Image.network(
                            userPhotoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Image.asset(
                                  "assets/images/dp.png",
                                  fit: BoxFit.cover,
                                ),
                          )
                        : (localProfileImage != null &&
                              localProfileImage.isNotEmpty)
                        ? Image.network(
                            localProfileImage,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Image.asset(
                                  "assets/images/dp.png",
                                  fit: BoxFit.cover,
                                ),
                          )
                        : Image.asset(
                            "assets/images/dp.png",
                            fit: BoxFit.cover,
                          ),
                  ),
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

          // Delete Account Button
          GestureDetector(
            onTap: () {
              _showDeleteAccountDialog();
            },
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.red[100]!),
              ),
              child: Row(
                children: const [
                  Icon(Icons.delete_forever, color: Colors.red),
                  SizedBox(width: 15),
                  Text(
                    "Supprimer le compte",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 15),

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

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Supprimer le compte"),
          content: const Text(
            "Êtes-vous sûr de vouloir supprimer votre compte ? Cette action est irréversible.",
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
              onPressed: () async {
                Navigator.pop(context); // Close the confirm dialog
                _performDeleteAccount();
              },
              child: const Text(
                "Supprimer",
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
  }

  Future<void> _performDeleteAccount() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF6900)),
        );
      },
    );

    try {
      final loginProvider = Provider.of<LoginProvider>(context, listen: false);
      final success = await loginProvider.deleteAccount();

      if (mounted) {
        Navigator.pop(context); // Dismiss the loading dialog
      }

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Votre compte a été supprimé avec succès."),
              backgroundColor: Colors.green,
            ),
          );
        }
        widget.onLogout();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Échec de la suppression du compte. Veuillez réessayer.",
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Dismiss loading dialog if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Une erreur est survenue: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
