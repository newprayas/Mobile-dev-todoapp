import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../screens/login_screen.dart';
import '../screens/todo_list_screen.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class AuthWrapper extends StatefulWidget {
  final ApiService api;
  final AuthService auth;
  final NotificationService notificationService;

  const AuthWrapper({
    required this.api,
    required this.auth,
    required this.notificationService,
    super.key,
  });

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
    // Listen to auth changes
    widget.auth.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) {
      setState(() {
        // Just trigger a rebuild when auth state changes
      });
    }
  }

  Future<void> _checkAuthStatus() async {
    try {
      await widget.auth.loadSavedToken();
      if (kDebugMode)
        debugPrint(
          'DEBUG: Auth status checked: ${widget.auth.isAuthenticated}',
        );
    } catch (error) {
      if (kDebugMode) debugPrint('DEBUG: Error checking auth status: $error');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.auth.isAuthenticated) {
      if (kDebugMode)
        debugPrint('DEBUG: User is authenticated, showing TodoListScreen');
      return TodoListScreen(
        api: widget.api,
        auth: widget.auth,
        notificationService: widget.notificationService,
      );
    } else {
      if (kDebugMode)
        debugPrint('DEBUG: User is not authenticated, showing LoginScreen');
      return LoginScreen(api: widget.api, auth: widget.auth);
    }
  }
}
