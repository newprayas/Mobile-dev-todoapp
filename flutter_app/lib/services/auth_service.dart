import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'api_service.dart';

class AuthService {
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  final ApiService api;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  AuthService(this.api);

  Future<bool> signInWithGoogle() async {
    try {
      final GoogleSignInAccount account = await _googleSignIn.authenticate();
      final GoogleSignInAuthentication auth = account.authentication;
      if (auth.idToken == null) {
        return false;
      }
      return await signInWithIdToken(auth.idToken!);
    } catch (error) {
      if (kDebugMode) debugPrint("Google Sign-In error: $error");
      return false;
    }
  }

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
    await _googleSignIn.signOut();
    await _secure.delete(key: 'server_token');
    api.setAuthToken(null);
  }

  Future<void> loadSavedToken() async {
    // Ensure GoogleSignIn is initialized before any authenticate/signIn calls.
    await _googleSignIn.initialize();
    final t = await _secure.read(key: 'server_token');
    if (t != null) api.setAuthToken(t);
  }
}
