import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert'; // For json encoding/decoding
import 'api_service.dart';
import '../utils/debug_logger.dart';

class AuthService extends ChangeNotifier {
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  final ApiService api; // Strongly typed instead of dynamic

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
  debugLog('AuthService', 'Initiating mock Google Sign-In...');

      // Generate a mock ID token and proceed with server authentication.
      final String mockIdToken =
          'mock_id_token_${DateTime.now().millisecondsSinceEpoch}';
      debugLog(
        'AuthService',
        'Generated mock token: ${mockIdToken.substring(0, 20)}...',
      );

  final bool result = await signInWithIdToken(mockIdToken);
  debugLog('AuthService', 'signInWithIdToken returned: $result');
      return result;
    } catch (error, stackTrace) {
      debugLog('AuthService', 'Mock sign-in error: $error');
      debugLog('AuthService', 'Stack trace: $stackTrace');
      return false;
    }
  }

  Future<bool> signInWithIdToken(String idToken) async {
    try {
  if (kDebugMode) debugLog('AuthService', 'Sending ID token to backend...');
  debugLog('AuthService', 'API instance type: ${api.runtimeType}');

  final Map<String, dynamic> resp = await api.authWithIdToken(idToken);
  debugLog('AuthService', 'Backend response received: $resp');

      final dynamic token = resp['token'];
      final dynamic user = resp['user'];

      if (token != null && user != null) {
        debugLog(
          'AuthService',
          'Valid token and user received, storing credentials...',
        );
        await _secure.write(key: 'server_token', value: token as String);
        // Store user data as a JSON string for better structure
        await _secure.write(key: 'user_data', value: json.encode(user));

        api.setAuthToken(token as String?);
        _currentUser = user as Map<String, dynamic>;
        _isAuthenticated = true;

        if (kDebugMode) {
          debugLog(
            'AuthService',
            'Authentication successful for user: ${user['email']}',
          );
        }
        debugLog('AuthService', 'Calling notifyListeners...');
        notifyListeners();
        return true;
      }

      if (kDebugMode) debugLog('AuthService', 'No token received from backend');
      return false;
    } catch (error, stackTrace) {
      if (kDebugMode) debugLog('AuthService', 'Backend authentication error: $error');
      if (kDebugMode) debugLog('AuthService', 'Stack trace: $stackTrace');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
  if (kDebugMode) debugLog('AuthService', 'Signing out...');

      await _secure.delete(key: 'server_token');
      await _secure.delete(key: 'user_data');

      api.setAuthToken(null);
      _currentUser = null;
      _isAuthenticated = false;

      if (kDebugMode) debugLog('AuthService', 'Sign out complete');
      notifyListeners();
    } catch (error) {
      if (kDebugMode) debugLog('AuthService', 'Sign out error: $error');
    }
  }

  Future<void> loadSavedToken() async {
    try {
      final String? token = await _secure.read(key: 'server_token');
      final String? userDataString = await _secure.read(key: 'user_data');

      if (token != null) {
        api.setAuthToken(token);
        _isAuthenticated = true;

        if (userDataString != null) {
          // Decode the user data from JSON
            _currentUser = json.decode(userDataString) as Map<String, dynamic>;
        }

        if (kDebugMode) debugLog('AuthService', 'Loaded saved authentication');
        notifyListeners();
      }
    } catch (error) {
      if (kDebugMode) debugLog('AuthService', 'Error loading saved token: $error');
    }
  }

  Future<bool> checkAuthStatus() async {
    final String? token = await _secure.read(key: 'server_token');
    _isAuthenticated = token != null;
    notifyListeners();
    return _isAuthenticated;
  }
}
