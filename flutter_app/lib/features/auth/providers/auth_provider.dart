import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/mock_api_service.dart';

// Auth state class
class AuthState {
  final bool isAuthenticated;
  final String email;
  final String userName;
  final Map<String, dynamic>? currentUser;

  const AuthState({
    this.isAuthenticated = false,
    this.email = '',
    this.userName = '',
    this.currentUser,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? email,
    String? userName,
    Map<String, dynamic>? currentUser,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      email: email ?? this.email,
      userName: userName ?? this.userName,
      currentUser: currentUser ?? this.currentUser,
    );
  }
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  late AuthService _authService;

  @override
  Future<AuthState> build() async {
    final apiService = ref.watch(apiServiceProvider);
    _authService = AuthService(apiService);

    // Load saved token and check current state
    await _authService.loadSavedToken();
    await _authService.checkAuthStatus();

    return AuthState(
      isAuthenticated: _authService.isAuthenticated,
      email: _authService.userEmail ?? '',
      userName: _authService.userName ?? '',
      currentUser: _authService.currentUser,
    );
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final success = await _authService.signInWithGoogle();
      if (success) {
        return AuthState(
          isAuthenticated: _authService.isAuthenticated,
          email: _authService.userEmail ?? '',
          userName: _authService.userName ?? '',
          currentUser: _authService.currentUser,
        );
      } else {
        throw Exception('Google Sign-In failed');
      }
    });
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authService.signOut();
      return const AuthState();
    });
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authService.checkAuthStatus();
      return AuthState(
        isAuthenticated: _authService.isAuthenticated,
        email: _authService.userEmail ?? '',
        userName: _authService.userName ?? '',
        currentUser: _authService.currentUser,
      );
    });
  }
}

// Auth provider
final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
