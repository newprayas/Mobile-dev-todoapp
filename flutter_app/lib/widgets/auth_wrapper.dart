import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/login_screen.dart';
import '../screens/todo_list_screen.dart';
import '../providers/auth_provider.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return authState.when(
      data: (authData) {
        if (authData.isAuthenticated) {
          if (kDebugMode) {
            debugPrint('DEBUG: User is authenticated, showing TodoListScreen');
          }
          return const TodoListScreen();
        } else {
          if (kDebugMode) {
            debugPrint('DEBUG: User is not authenticated, showing LoginScreen');
          }
          return const LoginScreen();
        }
      },
      loading: () => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) {
        if (kDebugMode) debugPrint('DEBUG: Auth error: $error');
        return const LoginScreen(); // Fallback to login on error
      },
    );
  }
}
