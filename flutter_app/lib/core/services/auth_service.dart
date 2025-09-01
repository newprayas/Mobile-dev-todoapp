import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert'; // For json encoding/decoding

class AuthService extends ChangeNotifier {
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  final dynamic api;

  Map<String, dynamic>? _currentUser;
  bool _isAuthenticated = false;

  AuthService(this.api);

  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  String? get userEmail => _currentUser?['email'];
  String? get userName => _currentUser?['name'] ?? _currentUser?['email'];

  Future<bool> signInWithGoogle() async {
    try {
      // Always use mock Google Sign-In for tester APKs (no real plugin calls).
      debugPrint('AUTH: Initiating mock Google Sign-In...');

      // Generate a mock ID token and proceed with server authentication.
      final mockIdToken =
          'mock_id_token_${DateTime.now().millisecondsSinceEpoch}';
      debugPrint(
        'AUTH: Generated mock token: ${mockIdToken.substring(0, 20)}...',
      );

      final result = await signInWithIdToken(mockIdToken);
      debugPrint('AUTH: signInWithIdToken returned: $result');
      return result;
    } catch (error, stackTrace) {
      debugPrint("AUTH: Mock sign-in error: $error");
      debugPrint("AUTH: Stack trace: $stackTrace");
      return false;
    }
  }

  Future<bool> signInWithIdToken(String idToken) async {
    try {
      if (kDebugMode) debugPrint('AUTH: Sending ID token to backend...');
      debugPrint('AUTH: API instance type: ${api.runtimeType}');

      final resp = await api.authWithIdToken(idToken);
      debugPrint('AUTH: Backend response received: $resp');

      final token = resp['token'];
      final user = resp['user'];

      if (token != null && user != null) {
        debugPrint(
          'AUTH: Valid token and user received, storing credentials...',
        );
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
        debugPrint('AUTH: Calling notifyListeners...');
        notifyListeners();
        return true;
      }

      if (kDebugMode) debugPrint('AUTH: No token received from backend');
      return false;
    } catch (error, stackTrace) {
      if (kDebugMode) debugPrint('AUTH: Backend authentication error: $error');
      if (kDebugMode) debugPrint('AUTH: Stack trace: $stackTrace');
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
