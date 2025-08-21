import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

class AuthService {
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  final ApiService api;

  AuthService(this.api);

  // Mobile sign-in flow will be implemented later using google_sign_in or
  // Google Identity Services. For now provide a helper that exchanges an
  // idToken with the backend and stores the server token.
  Future<bool> signInWithIdToken(String idToken) async {
    final resp = await api.authWithIdToken(idToken);
    final token = resp['token'];
    if (token != null) {
      await _secure.write(key: 'server_token', value: token);
      api.setAuthToken(token);
      return true;
    }
    return false;
  }

  Future<void> signOut() async {
    await _secure.delete(key: 'server_token');
    api.setAuthToken(null);
  }

  Future<void> loadSavedToken() async {
    final t = await _secure.read(key: 'server_token');
    if (t != null) api.setAuthToken(t);
  }
}
