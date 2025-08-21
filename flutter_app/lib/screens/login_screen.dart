import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatelessWidget {
  final ApiService api;
  final AuthService auth;
  const LoginScreen({required this.api, required this.auth, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: ElevatedButton(
          child: const Text('Continue (placeholder)'),
          onPressed: () {
            Navigator.of(context).pushReplacementNamed('/todos');
          },
        ),
      ),
    );
  }
}
