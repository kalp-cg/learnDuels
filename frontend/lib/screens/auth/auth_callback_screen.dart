import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthCallbackScreen extends ConsumerStatefulWidget {
  const AuthCallbackScreen({super.key});

  @override
  ConsumerState<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends ConsumerState<AuthCallbackScreen> {
  @override
  void initState() {
    super.initState();
    // Wait for the widget to be fully built before handling callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleCallback();
    });
  }

  Future<void> _handleCallback() async {
    try {
      // Get tokens from GoRouter state
      final state = GoRouterState.of(context);
      final accessToken = state.uri.queryParameters['access_token'];
      final refreshToken = state.uri.queryParameters['refresh_token'];

      debugPrint('🔍 Full URI: ${state.uri}');
      debugPrint('🔑 Access Token: ${accessToken?.substring(0, 20)}...');
      debugPrint('🔑 Refresh Token: ${refreshToken?.substring(0, 20)}...');

      if (accessToken == null || refreshToken == null) {
        throw Exception('Tokens not found in URL');
      }

      // Save tokens to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('accessToken', accessToken);
      await prefs.setString('refreshToken', refreshToken);

      debugPrint('✅ Tokens saved successfully');

      // Small delay to ensure storage is complete
      await Future.delayed(const Duration(milliseconds: 500));

      // Navigate to home
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      debugPrint('❌ Error handling auth callback: $e');

      // Show error and go back to login
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication failed: $e'),
            backgroundColor: Colors.red,
          ),
        );

        // Small delay before navigation
        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          context.go('/login');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Icon(Icons.check, size: 50, color: Colors.green),
            ),
            const SizedBox(height: 24),
            Text(
              'Login Successful!',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Setting up your account...',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(
                  context,
                ).textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
