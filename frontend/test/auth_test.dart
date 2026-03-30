import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_new/providers/auth_provider.dart';
import 'package:frontend_new/core/services/auth_service.dart';

// Mock AuthService
class MockAuthService implements AuthService {
  bool shouldFail = false;

  @override
  Future<String?> login(String email, String password) async {
    if (shouldFail) {
      return 'Invalid credentials';
    }
    return null; // Success
  }

  @override
  Future<String?> register(
    String username,
    String email,
    String password,
    String fullName,
  ) async {
    return null;
  }

  @override
  Future<void> logout() async {}

  @override
  Future<bool> isLoggedIn() async => false;

  @override
  // method not needed for test but usually required by implementation if we used 'extends'
  // but 'implements' requires all members.
  // checking original file, it has a final Dio _dio; but interfaces don't require private members.
  // Getter for public members if any? No.
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AuthNotifier Tests', () {
    test('Login success updates state to data', () async {
      final mockAuthService = MockAuthService();
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
      );

      final notifier = container.read(authStateProvider.notifier);

      // Initial state is data(null)
      expect(
        container.read(authStateProvider),
        const AsyncValue<void>.data(null),
      );

      // Perform login
      final result = await notifier.login('test@test.com', 'password');

      expect(result, true);
      expect(
        container.read(authStateProvider),
        const AsyncValue<void>.data(null),
      );
    });

    test('Login failure updates state to error', () async {
      final mockAuthService = MockAuthService();
      mockAuthService.shouldFail = true;

      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
      );

      final notifier = container.read(authStateProvider.notifier);

      // Perform login
      final result = await notifier.login('test@test.com', 'wrongpassword');

      expect(result, false);
      expect(container.read(authStateProvider) is AsyncError, true);
      expect(container.read(authStateProvider).error, 'Invalid credentials');
    });
  });
}
