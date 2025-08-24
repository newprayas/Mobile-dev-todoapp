import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final ApiService api;
  final AuthService auth;
  const LoginScreen({required this.api, required this.auth, super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSigningIn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: _isSigningIn
            ? const CircularProgressIndicator()
            : ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Sign in with Google'),
                onPressed: () async {
                  setState(() {
                    _isSigningIn = true;
                  });
                  final success = await widget.auth.signInWithGoogle();
                  if (!mounted) return;
                  if (success) {
                    Navigator.of(context).pushReplacementNamed('/todos');
                  } else {
                    setState(() {
                      _isSigningIn = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Google Sign-In failed. Please try again.',
                        ),
                      ),
                    );
                  }
                },
              ),
      ),
    );
  }
}
