import 'package:binetatour/core/login/login_provider.dart';
import 'package:binetatour/providers/cart_provider.dart';
import 'package:binetatour/providers/notification_provider.dart';
import 'package:binetatour/providers/order_provider.dart';
import 'package:binetatour/core/widgets/shimmer/cool_shimmer_kit.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoginProvider>();

    return Scaffold(
      appBar: AppBar(title: Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: "Password"),
            ),
            const SizedBox(height: 20),

            provider.isLoading
                ? const CoolShimmer(
                    child: CoolShimmerBone.pill(width: 80, height: 35),
                  )
                : ElevatedButton(
                    onPressed: () async {
                      await provider.login(
                        emailController.text.trim(),
                        passwordController.text.trim(),
                      );
                      if (!mounted) return;
                      await Future.wait([
                        context.read<CartProvider>().fetchCart().catchError((e) {
                          debugPrint("Error fetching cart: $e");
                        }),
                        context.read<NotificationProvider>().fetchNotifications().catchError((e) {
                          debugPrint("Error fetching notifications: $e");
                        }),
                        context.read<OrderProvider>().fetchOrderHistory().catchError((e) {
                          debugPrint("Error fetching order history: $e");
                        }),
                      ]);
                      if (!mounted) return;
                      Navigator.pop(context);
                    },
                    child: Text("Login"),
                  ),
          ],
        ),
      ),
    );
  }
}
