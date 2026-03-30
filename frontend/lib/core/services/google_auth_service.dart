import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoogleAuthService {
  final Dio _dio;

  // Configure Google Sign-In with clientId required for mobile OAuth flow
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    clientId: const String.fromEnvironment(
      'GOOGLE_CLIENT_ID',
      defaultValue:
          '171390706156-v9947fn6ttjjq82gqf515ec2cele988d.apps.googleusercontent.com',
    ),
  );

  GoogleAuthService(this._dio);

  /// Sign in with Google (Mobile Native Flow)
  Future<String?> signInWithGoogle() async {
    try {
      debugPrint('🔵 Starting Google Sign-In...');

      // Check if running on web
      if (kIsWeb) {
        debugPrint('❌ Google Sign-In is not supported on web platform');
        return 'Google Sign-In is only available on mobile devices';
      }

      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('❌ User cancelled Google Sign-In');
        return 'Sign-in cancelled';
      }

      debugPrint('✅ Google user signed in: ${googleUser.email}');

      // Get authentication tokens from Google
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null) {
        return 'Failed to get Google access token';
      }

      debugPrint('🔑 Got Google access token');

      // Send Google token to our backend
      final response = await _dio.post(
        '/auth/google/mobile',
        data: {
          'accessToken': googleAuth.accessToken,
          'idToken': googleAuth.idToken,
        },
      );

      if (response.data == null || response.data['success'] != true) {
        return 'Authentication with backend failed';
      }

      // Extract and save our JWT tokens
      final data = response.data['data'];
      final accessToken = data['accessToken'];
      final refreshToken = data['refreshToken'];

      if (accessToken == null || refreshToken == null) {
        return 'Missing tokens in response';
      }

      // Save tokens
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('accessToken', accessToken);
      await prefs.setString('refreshToken', refreshToken);

      debugPrint('✅ Google Sign-In successful');
      return null; // Success
    } catch (e) {
      debugPrint('❌ Google Sign-In error: $e');
      return 'Google Sign-In failed: $e';
    }
  }

  /// Sign out from Google
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      debugPrint('✅ Signed out from Google');
    } catch (e) {
      debugPrint('❌ Error signing out from Google: $e');
    }
  }

  /// Check if user is signed in with Google
  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }
}
