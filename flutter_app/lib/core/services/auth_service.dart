import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  final ApiService api;

  // User state management
  Map<String, dynamic>? _currentUser;
  bool _isAuthenticated = false;

  AuthService(this.api);

  // Getters
  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  String? get userEmail => _currentUser?['email'];
  String? get userName => _currentUser?['name'] ?? _currentUser?['email'];

  Future<bool> signInWithGoogle() async {
    try {
      if (kDebugMode) debugPrint('DEBUG: Starting Google Sign-In...');

      // For development, we'll use a mock flow since real Google Sign-In setup requires OAuth configuration
      if (kDebugMode) {
        debugPrint('DEBUG: Using development mode sign-in');
        return await _mockSignIn();
      }

      // This would be used for real Google Sign-In in production
      return await _mockSignIn();
    } catch (error) {
      if (kDebugMode) debugPrint("DEBUG: Google Sign-In error: $error");
      // Fall back to mock for development
      if (kDebugMode) {
        debugPrint('DEBUG: Falling back to mock sign-in due to error');
        return await _mockSignIn();
      }
      return false;
    }
  }

  Future<bool> _mockSignIn() async {
    try {
      if (kDebugMode) {
        debugPrint('DEBUG: Performing mock sign-in for development');
      }

      // Create a mock ID token for development
      final mockIdToken =
          'mock_id_token_${DateTime.now().millisecondsSinceEpoch}';
      return await signInWithIdToken(mockIdToken);
    } catch (error) {
      if (kDebugMode) debugPrint('DEBUG: Mock sign-in error: $error');
      return false;
    }
  }

  Future<bool> signInWithIdToken(String idToken) async {
    try {
      if (kDebugMode) debugPrint('DEBUG: Sending ID token to backend...');
      final resp = await api.authWithIdToken(idToken);

      final token = resp['token'];
      final user = resp['user'];

      if (token != null) {
        await _secure.write(key: 'server_token', value: token);
        if (user != null) {
          await _secure.write(key: 'user_data', value: user.toString());
        }

        api.setAuthToken(token);
        _currentUser = user ?? {'email': 'dev@example.com', 'name': 'Dev User'};
        _isAuthenticated = true;

        if (kDebugMode) {
          debugPrint(
            'DEBUG: Authentication successful for user: ${_currentUser?['email']}',
          );
        }
        notifyListeners();
        return true;
      }

      if (kDebugMode) debugPrint('DEBUG: No token received from backend');
      return false;
    } catch (error) {
      if (kDebugMode) debugPrint('DEBUG: Backend authentication error: $error');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      if (kDebugMode) debugPrint('DEBUG: Signing out...');

      await _secure.delete(key: 'server_token');
      await _secure.delete(key: 'user_data');

      api.setAuthToken(null);
      _currentUser = null;
      _isAuthenticated = false;

      if (kDebugMode) debugPrint('DEBUG: Sign out complete');
      notifyListeners();
    } catch (error) {
      if (kDebugMode) debugPrint('DEBUG: Sign out error: $error');
    }
  }

  Future<void> loadSavedToken() async {
    try {
      final token = await _secure.read(key: 'server_token');
      final userData = await _secure.read(key: 'user_data');

      if (token != null) {
        api.setAuthToken(token);
        _isAuthenticated = true;

        if (userData != null) {
          // Parse user data (this is a simple string conversion, in production use JSON)
          _currentUser = {'email': 'saved@example.com', 'name': 'Saved User'};
        }

        if (kDebugMode) debugPrint('DEBUG: Loaded saved authentication');
        notifyListeners();
      }
    } catch (error) {
      if (kDebugMode) debugPrint('DEBUG: Error loading saved token: $error');
    }
  }

  Future<bool> checkAuthStatus() async {
    final token = await _secure.read(key: 'server_token');
    _isAuthenticated = token != null;
    notifyListeners();
    return _isAuthenticated;
  }
}
