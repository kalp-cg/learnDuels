import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/auth_service.dart';

final authStateProvider = StateNotifierProvider<AuthNotifier, AsyncValue<void>>(
  (ref) {
    final authService = ref.watch(authServiceProvider);
    return AuthNotifier(authService);
  },
);

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(AsyncValue.data(null));

  Future<bool> login(String email, String password) async {
    debugPrint('🔐 AuthNotifier: Starting login...');
    state = AsyncValue.loading();
    final error = await _authService.login(email, password);

    if (error != null) {
      debugPrint('❌ AuthNotifier: Login failed with error: $error');
      state = AsyncValue.error(error, StackTrace.current);
      return false;
    } else {
      debugPrint('✅ AuthNotifier: Login successful!');
      state = AsyncValue.data(null);
      return true;
    }
  }

  Future<bool> loginWithGoogle(String idToken, String accessToken) async {
    debugPrint('🔐 AuthNotifier: Starting Google login...');
    state = AsyncValue.loading();
    final error = await _authService.loginWithGoogle(idToken, accessToken);

    if (error != null) {
      debugPrint('❌ AuthNotifier: Google Login failed with error: $error');
      state = AsyncValue.error(error, StackTrace.current);
      return false;
    } else {
      debugPrint('✅ AuthNotifier: Google Login successful!');
      state = AsyncValue.data(null);
      return true;
    }
  }

  Future<bool> register(
    String username,
    String email,
    String password,
    String fullName,
  ) async {
    state = AsyncValue.loading();
    final error = await _authService.register(
      username,
      email,
      password,
      fullName,
    );

    if (error != null) {
      state = AsyncValue.error(error, StackTrace.current);
      return false;
    } else {
      state = AsyncValue.data(null);
      return true;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
  }
}
