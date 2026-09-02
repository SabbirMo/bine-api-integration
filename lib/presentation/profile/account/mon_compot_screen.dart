import 'package:binetatour/core/login/login_provider.dart';
import 'package:binetatour/core/network/dio_client/dio_client.dart';
import 'package:binetatour/presentation/profile/widget/profile_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:binetatour/providers/cart_provider.dart';
import 'package:binetatour/providers/notification_provider.dart';
import 'package:binetatour/providers/order_provider.dart';

import '../widget/login_view.dart';

class MonCompteScreen extends StatelessWidget {
  const MonCompteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LoginProvider>(
      builder: (context, loginProvider, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text(
              "Mon Compte",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.white,
            elevation: 0,
          ),
          body: loginProvider.isLoggedIn
              ? ProfileView(
                  onLogout: () async {
                    if (context.mounted) {
                      await context.read<LoginProvider>().logout();
                    }
                    DioClient.reset();
                    if (context.mounted) {
                      context.read<CartProvider>().clearCart();
                      context.read<NotificationProvider>().clearNotifications();
                      context.read<OrderProvider>().clearOrders();
                    }
                  },
                )
              : LoginView(
                  onLogin: () {
                    // Consumer automatically updates on loginProvider changes
                  },
                ),
        );
      },
    );
  }
}
