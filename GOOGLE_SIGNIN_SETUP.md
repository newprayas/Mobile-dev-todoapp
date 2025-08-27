# Google Sign-In Setup Guide

This guide shows you how to set up real Google Sign-In for your TodoApp Flutter application.

## Current Status
✅ **Development Mode**: The app currently uses mock authentication for development  
🔄 **Ready for Production**: All the infrastructure is in place for real Google Sign-In

## For Production Google Sign-In Setup

### Step 1: Google Cloud Console Setup
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the Google Sign-In API
4. Go to "Credentials" → "Create Credentials" → "OAuth 2.0 Client IDs"

### Step 2: Create OAuth Credentials

#### For Android:
1. Select "Android" as application type
2. Get your app's SHA-1 fingerprint:
   ```bash
   cd flutter_app/android
   ./gradlew signingReport
   ```
3. Add the SHA-1 fingerprint to your OAuth client
4. Set package name: `com.example.flutter_app`

#### For iOS:
1. Select "iOS" as application type  
2. Set Bundle ID: `com.example.flutterApp`

#### For Web:
1. Select "Web application" as application type
2. Add authorized origins (e.g., `http://localhost`, `https://yourdomain.com`)

### Step 3: Download Configuration Files

#### Android:
1. Download `google-services.json`
2. Replace `/flutter_app/android/app/google-services.json` with the real file

#### iOS:
1. Download `GoogleService-Info.plist`
2. Add it to `/flutter_app/ios/Runner/GoogleService-Info.plist`

### Step 4: Update the Code

In `/flutter_app/lib/services/auth_service.dart`, replace the mock sign-in with real Google Sign-In:

```dart
Future<bool> signInWithGoogle() async {
  try {
    if (kDebugMode) debugPrint('DEBUG: Starting Google Sign-In...');
    
    // Use real Google Sign-In in production
    final GoogleSignIn googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
    );
    
    final GoogleSignInAccount? account = await googleSignIn.signIn();
    if (account == null) {
      if (kDebugMode) debugPrint('DEBUG: Google Sign-In cancelled by user');
      return false;
    }
    
    final GoogleSignInAuthentication auth = await account.authentication;
    if (auth.idToken == null) {
      if (kDebugMode) debugPrint('DEBUG: Failed to get ID token');
      return false;
    }
    
    return await signInWithIdToken(auth.idToken!);
  } catch (error) {
    if (kDebugMode) debugPrint("DEBUG: Google Sign-In error: $error");
    return false;
  }
}
```

### Step 5: Backend Token Verification (Important for Production)

The current backend accepts any ID token for development. For production, update `/backend/bin/server.dart`:

```dart
Future<Response> authWithIdToken(Request request) async {
  try {
    final payload = json.decode(await request.readAsString()) as Map<String, dynamic>;
    final idToken = payload['id_token'] as String?;
    
    if (idToken == null || idToken.isEmpty) {
      return jsonResponse({'error': 'Missing id_token'}, status: 400);
    }
    
    // TODO: Verify Google ID token here
    // Use a library like 'googleapis_auth' to verify the token
    // Verify signature, expiration, issuer, audience, etc.
    
    final serverToken = 'server_token_${DateTime.now().millisecondsSinceEpoch}';
    
    return jsonResponse({
      'token': serverToken,
      'user': {
        'id': 'verified_google_user',
        'email': 'user@gmail.com', // Extract from verified token
        'name': 'User Name' // Extract from verified token
      }
    });
  } catch (e) {
    return jsonResponse({'error': 'Invalid request'}, status: 400);
  }
}
```

## Testing

### Development Testing
- The current setup works out of the box for development
- Uses mock authentication that works without Google Cloud setup

### Production Testing
1. Test on a real device (not emulator)
2. Ensure internet connection
3. Test sign-in flow
4. Verify token persistence
5. Test sign-out functionality

## Security Notes

- Never commit real `google-services.json` or `GoogleService-Info.plist` to version control
- Add these files to `.gitignore`
- Use environment variables for sensitive configuration
- Implement proper token verification on the backend
- Use HTTPS in production

## Current Files Structure

```
flutter_app/
├── android/app/google-services.json    # ✅ Development placeholder
├── ios/Runner/GoogleService-Info.plist # ❌ Missing (add for iOS)
├── lib/services/auth_service.dart      # ✅ Ready for production
└── lib/screens/login_screen.dart       # ✅ Complete UI

backend/
└── bin/server.dart                     # ✅ Has auth endpoint (needs token verification)
```

## Development vs Production

| Feature | Development | Production |
|---------|-------------|------------|
| Authentication | Mock | Real Google OAuth |
| Configuration | Placeholder files | Real Google services files |
| Token Verification | None | Required |
| User Data | Mock | Real Google profile |
| Testing | Works offline | Requires internet |
