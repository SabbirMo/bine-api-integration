import 'package:binetatour/auth/auth_service.dart';
import 'package:binetatour/core/login/login_provider.dart';
import 'package:binetatour/core/token_storage/token_storage.dart';
import 'package:binetatour/core/network/dio_client/dio_client.dart';
import 'package:binetatour/presentation/profile/widget/profile_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:binetatour/providers/cart_provider.dart';
import 'package:binetatour/providers/notification_provider.dart';
import 'package:binetatour/providers/order_provider.dart';

import '../widget/login_view.dart';

class MonCompteScreen extends StatefulWidget {
  const MonCompteScreen({super.key});

  @override
  State<MonCompteScreen> createState() => _MonCompteScreenState();
}

class _MonCompteScreenState extends State<MonCompteScreen> {
  bool _isLoggedIn = false;
  bool _isLoading = true;
  LoginProvider? _loginProvider;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newProvider = Provider.of<LoginProvider>(context, listen: false);
    if (_loginProvider != newProvider) {
      _loginProvider?.removeListener(_checkLoginStatus);
      _loginProvider = newProvider;
      _loginProvider?.addListener(_checkLoginStatus);
    }
  }

  @override
  void dispose() {
    _loginProvider?.removeListener(_checkLoginStatus);
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    final token = await TokenStorage.getAccessToken();
    if (mounted) {
      setState(() {
        _isLoggedIn = token != null && token.isNotEmpty;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFF6900),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Mon Compte",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      // Switch between LoginView and ProfileView dynamically
      body: _isLoggedIn
          ? ProfileView(
              onLogout: () async {
                await TokenStorage.clearTokens();
                await AuthService().signOut();
                DioClient.reset(); // Reset Dio so headers are cleared and clean next session
                if (context.mounted) {
                  context.read<CartProvider>().clearCart();
                  context.read<NotificationProvider>().clearNotifications();
                  context.read<OrderProvider>().clearOrders();
                }
                _checkLoginStatus();
              },
            )
          : LoginView(
              onLogin: () {
                _checkLoginStatus();
              },
            ),
    );
  }
}
