import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

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
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text(
          'Sign In',
          style: TextStyle(color: AppColors.lightGray),
        ),
        backgroundColor: AppColors.scaffoldBg,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo/Title
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.brightYellow.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.task_alt,
                  size: 80,
                  color: AppColors.brightYellow,
                ),
              ),
              const SizedBox(height: 32),

              // Welcome Text
              Text(
                'Welcome to TodoApp',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.lightGray,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Sign in with Google to sync your tasks across devices',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.lightGray.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 48),

              // Sign In Button or Loading
              _isSigningIn
                  ? Column(
                      children: [
                        CircularProgressIndicator(
                          color: AppColors.brightYellow,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Signing you in...',
                          style: TextStyle(
                            color: AppColors.lightGray.withOpacity(0.7),
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brightYellow,
                          foregroundColor: AppColors.scaffoldBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.login, size: 24),
                        label: const Text(
                          'Sign in with Google',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () async {
                          setState(() {
                            _isSigningIn = true;
                          });

                          if (kDebugMode)
                            debugPrint('DEBUG: Login button pressed');

                          final success = await widget.auth.signInWithGoogle();
                          if (!mounted) return;

                          if (success) {
                            if (kDebugMode)
                              debugPrint(
                                'DEBUG: Login successful, navigating to todos',
                              );
                            Navigator.of(
                              context,
                            ).pushReplacementNamed('/todos');
                          } else {
                            setState(() {
                              _isSigningIn = false;
                            });

                            if (kDebugMode)
                              debugPrint('DEBUG: Login failed, showing error');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Google Sign-In failed. Please try again.',
                                ),
                                backgroundColor: Colors.red.shade600,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                    ),

              const SizedBox(height: 24),

              // Development Note
              if (kDebugMode)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.brightYellow.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.brightYellow.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.brightYellow,
                        size: 20,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Development Mode',
                        style: TextStyle(
                          color: AppColors.brightYellow,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Using mock authentication for development. In production, this will use real Google Sign-In.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.lightGray.withOpacity(0.8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
