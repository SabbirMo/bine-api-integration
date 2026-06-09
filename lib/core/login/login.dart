import 'package:binetatour/core/login/login_provider.dart';
import 'package:binetatour/providers/cart_provider.dart';
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
                ? SizedBox(
                    height: 35,
                    width: 35,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : ElevatedButton(
                    onPressed: () async {
                      await provider.login(
                        emailController.text.trim(),
                        passwordController.text.trim(),
                      );
                      if (!mounted) return;
                      // Fetch cart data after successful login to update badge
                      context.read<CartProvider>().fetchCart();
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
