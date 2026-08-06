import 'package:binetatour/core/login/login_provider.dart';
import 'package:binetatour/providers/cart_provider.dart';
import 'package:binetatour/providers/notification_provider.dart';
import 'package:binetatour/providers/order_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

class LoginView extends StatelessWidget {
  final VoidCallback onLogin;
  const LoginView({super.key, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    final loginProvider = Provider.of<LoginProvider>(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.orange[50],
            child: const Icon(Icons.person, size: 50, color: Colors.blueGrey),
          ),
          const SizedBox(height: 24),
          const Text(
            "Connectez-vous",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            "Connectez-vous pour suivre vos commandes, vos factures et gérer votre profil.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 40),
          OutlinedButton(
            onPressed: loginProvider.isGoogleLoading
                ? null
                : () async {
                    final success = await loginProvider.loginWithGoogle();
                    if (success) {
                      if (context.mounted) {
                        // Fetch cart, notifications, orders in background asynchronously
                        context.read<CartProvider>().fetchCart().catchError((
                          e,
                        ) {
                          debugPrint("Error fetching cart: $e");
                        });
                        context
                            .read<NotificationProvider>()
                            .fetchNotifications()
                            .catchError((e) {
                              debugPrint("Error fetching notifications: $e");
                            });
                        context
                            .read<OrderProvider>()
                            .fetchOrderHistory()
                            .catchError((e) {
                              debugPrint("Error fetching order history: $e");
                            });
                        onLogin();
                      }
                    } else if (context.mounted &&
                        loginProvider.errorMessage != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(loginProvider.errorMessage!),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            child: loginProvider.isGoogleLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.black,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        "assets/icon/google.svg",
                      ), // Use a local asset in production
                      const SizedBox(width: 12),
                      const Text(
                        "Se Continuer avec Google",
                        style: TextStyle(color: Colors.black, fontSize: 16),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: loginProvider.isAppleLoading
                ? null
                : () async {
                    final success = await loginProvider.loginWithApple();
                    if (success) {
                      if (context.mounted) {
                        context.read<CartProvider>().fetchCart().catchError((
                          e,
                        ) {
                          debugPrint("Error fetching cart: $e");
                        });
                        context
                            .read<NotificationProvider>()
                            .fetchNotifications()
                            .catchError((e) {
                              debugPrint("Error fetching notifications: $e");
                            });
                        context
                            .read<OrderProvider>()
                            .fetchOrderHistory()
                            .catchError((e) {
                              debugPrint("Error fetching order history: $e");
                            });
                        onLogin();
                      }
                    }
                  },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            child: loginProvider.isAppleLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.black,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset("assets/icon/apple.svg"),
                      const SizedBox(width: 12),
                      const Text(
                        "Continuer avec Apple",
                        style: TextStyle(color: Colors.black, fontSize: 16),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
