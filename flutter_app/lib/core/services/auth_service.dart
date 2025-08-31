import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';
import 'dart:convert'; // For json encoding/decoding

class AuthService extends ChangeNotifier {
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  final ApiService api;

  Map<String, dynamic>? _currentUser;
  bool _isAuthenticated = false;

  AuthService(this.api);

  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  String? get userEmail => _currentUser?['email'];
  String? get userName => _currentUser?['name'] ?? _currentUser?['email'];

  Future<bool> signInWithGoogle() async {
    try {
      if (kDebugMode)
        debugPrint('AUTH: Starting mock sign-in for deployment testing...');

      // Create a mock ID token for development/testing
      final mockIdToken =
          'mock_id_token_${DateTime.now().millisecondsSinceEpoch}';
      return await signInWithIdToken(mockIdToken);
    } catch (error) {
      if (kDebugMode) debugPrint("AUTH: Mock sign-in error: $error");
      return false;
    }
  }

  Future<bool> signInWithIdToken(String idToken) async {
    try {
      if (kDebugMode) debugPrint('AUTH: Sending ID token to backend...');
      final resp = await api.authWithIdToken(idToken);

      final token = resp['token'];
      final user = resp['user'];

      if (token != null && user != null) {
        await _secure.write(key: 'server_token', value: token);
        // Store user data as a JSON string for better structure
        await _secure.write(key: 'user_data', value: json.encode(user));

        api.setAuthToken(token);
        _currentUser = user;
        _isAuthenticated = true;

        if (kDebugMode) {
          debugPrint(
            'AUTH: Authentication successful for user: ${user['email']}',
          );
        }
        notifyListeners();
        return true;
      }

      if (kDebugMode) debugPrint('AUTH: No token received from backend');
      return false;
    } catch (error) {
      if (kDebugMode) debugPrint('AUTH: Backend authentication error: $error');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      if (kDebugMode) debugPrint('AUTH: Signing out...');

      await _secure.delete(key: 'server_token');
      await _secure.delete(key: 'user_data');

      api.setAuthToken(null);
      _currentUser = null;
      _isAuthenticated = false;

      if (kDebugMode) debugPrint('AUTH: Sign out complete');
      notifyListeners();
    } catch (error) {
      if (kDebugMode) debugPrint('AUTH: Sign out error: $error');
    }
  }

  Future<void> loadSavedToken() async {
    try {
      final token = await _secure.read(key: 'server_token');
      final userDataString = await _secure.read(key: 'user_data');

      if (token != null) {
        api.setAuthToken(token);
        _isAuthenticated = true;

        if (userDataString != null) {
          // Decode the user data from JSON
          _currentUser = json.decode(userDataString);
        }

        if (kDebugMode) debugPrint('AUTH: Loaded saved authentication');
        notifyListeners();
      }
    } catch (error) {
      if (kDebugMode) debugPrint('AUTH: Error loading saved token: $error');
    }
  }

  Future<bool> checkAuthStatus() async {
    final token = await _secure.read(key: 'server_token');
    _isAuthenticated = token != null;
    notifyListeners();
    return _isAuthenticated;
  }
}
