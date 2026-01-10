import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../widgets/custom_text_field.dart';
import '../../core/theme.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      debugPrint('🚀 Login button pressed');
      final success = await ref
          .read(authStateProvider.notifier)
          .login(_emailController.text.trim(), _passwordController.text);

      debugPrint('📊 Login result: $success, mounted: $mounted');

      if (success) {
        debugPrint('✅ Login success = true');
        if (mounted) {
          debugPrint('✅ Widget is mounted');
          debugPrint('🎯 Attempting navigation to /home...');

          try {
            Navigator.of(context).pushReplacementNamed('/home');
            debugPrint('✅ Navigation call completed');
          } catch (e) {
            debugPrint('❌ Navigation error: $e');
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Login Successful!',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
              ),
              backgroundColor: AppTheme.success,
            ),
          );
        } else {
          debugPrint('⚠️ Widget not mounted');
        }
      } else {
        debugPrint('❌ Login was not successful');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isLoading = authState is AsyncLoading;

    ref.listen(authStateProvider, (previous, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.error.toString(),
              style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    });

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppTheme.background,
        child: SafeArea(
          child: Stack(
            children: [
              // Background effects
              _buildBackgroundEffects(),

              // Main content
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28.0),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Logo with glow
                            _buildLogo(),
                            const SizedBox(height: 40),

                            // Welcome text
                            Text(
                              'Welcome Back',
                              style: GoogleFonts.outfit(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sign in to continue your progress',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w400,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 48),

                            // Email field
                            CustomTextField(
                              label: 'Email',
                              hint: 'Enter your email',
                              controller: _emailController,
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Password field
                            CustomTextField(
                              label: 'Password',
                              hint: 'Enter your password',
                              controller: _passwordController,
                              prefixIcon: Icons.lock_outline,
                              isPassword: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // Forgot password
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ForgotPasswordScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Forgot Password?',
                                  style: GoogleFonts.outfit(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Login button with gradient
                            _buildLoginButton(isLoading),
                            const SizedBox(height: 32),

                            // Divider
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: AppTheme.border.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    'or',
                                    style: GoogleFonts.outfit(
                                      color: AppTheme.textMuted,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: AppTheme.border.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),

                            // Social login buttons
                            Row(
                              children: [
                                // Google login
                                Expanded(
                                  child: _buildSocialButton(
                                    icon: Icons.g_mobiledata_rounded,
                                    label: 'Google',
                                    color: const Color(0xFFDB4437),
                                    onTap: () async {
                                      debugPrint(
                                        '🔵 Google Sign-In button pressed',
                                      );

                                      // Try the ID from .env (Android Client ID?) or the Web one.
                                      // We need the WEB Client ID here to get the idToken.
                                      // If this fails with 10, it means the Android App (SHA-1) is not in the same project as this ID.
                                      const webClientId =
                                          '171390706156-at1fq98p1s6uhps2v31r5kq5eosb0u3c.apps.googleusercontent.com';

                                      var googleSignIn = GoogleSignIn(
                                        serverClientId: webClientId,
                                        scopes: ['email', 'profile'],
                                      );

                                      try {
                                        try {
                                          await googleSignIn.disconnect();
                                        } catch (_) {}
                                        await googleSignIn.signOut();

                                        GoogleSignInAccount? account;
                                        try {
                                          account = await googleSignIn.signIn();
                                        } catch (e) {
                                          debugPrint(
                                            '⚠️ First attempt failed: $e',
                                          );
                                          if (e.toString().contains("10")) {
                                            debugPrint(
                                              '⚠️ ApiException: 10 detected. Retrying without serverClientId to diagnose...',
                                            );
                                            // Fallback: Try without serverClientId to see if basic auth works
                                            // This helps us know if the SHA-1 is correct but the Web Client ID is wrong
                                            googleSignIn = GoogleSignIn(
                                              scopes: ['email', 'profile'],
                                            );
                                            account = await googleSignIn
                                                .signIn();
                                            if (account != null) {
                                              debugPrint(
                                                '⚠️ Basic Auth worked! The Web Client ID was wrong.',
                                              );
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Setup Error: Web Client ID is invalid, but Android Auth is OK. Check Console.',
                                                    ),
                                                    backgroundColor:
                                                        AppTheme.warning,
                                                  ),
                                                );
                                              }
                                              return;
                                            }
                                          } else {
                                            rethrow;
                                          }
                                        }

                                        if (account == null) {
                                          debugPrint(
                                            '⚪ User cancelled Google Sign-In',
                                          );
                                          return;
                                        }

                                        debugPrint(
                                          '🟢 Google Sign-In success: ${account.email}',
                                        );

                                        // Get authentication tokens
                                        final auth =
                                            await account.authentication;
                                        final idToken = auth.idToken;
                                        final accessToken = auth.accessToken;

                                        debugPrint(
                                          '🔑 ID Token: ${idToken != null ? "Present" : "Missing"}',
                                        );
                                        debugPrint(
                                          '🔑 Access Token: ${accessToken != null ? "Present" : "Missing"}',
                                        );

                                        if (idToken == null ||
                                            accessToken == null) {
                                          debugPrint(
                                            '🔴 Missing Google tokens (ID: ${idToken != null}, Access: ${accessToken != null})',
                                          );
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Failed to get Google tokens. Check Web Client ID configuration.',
                                                ),
                                                backgroundColor: AppTheme.error,
                                              ),
                                            );
                                          }
                                          return;
                                        }

                                        // Call backend to login/register
                                        if (context.mounted) {
                                          final success = await ref
                                              .read(authStateProvider.notifier)
                                              .loginWithGoogle(
                                                idToken,
                                                accessToken,
                                              );

                                          if (success) {
                                            debugPrint(
                                              '✅ Backend login success',
                                            );
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Welcome ${account.displayName}!',
                                                  ),
                                                  backgroundColor:
                                                      AppTheme.success,
                                                ),
                                              );
                                              Navigator.of(
                                                context,
                                              ).pushReplacementNamed('/home');
                                            }
                                          } else {
                                            debugPrint(
                                              '❌ Backend login failed',
                                            );
                                          }
                                        }
                                      } catch (e) {
                                        debugPrint(
                                          '🔴 Google Sign-In error: $e',
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Google sign-in error: $e',
                                              ),
                                              backgroundColor: AppTheme.error,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // GitHub login
                                Expanded(
                                  child: _buildSocialButton(
                                    icon: Icons.code_rounded,
                                    label: 'GitHub',
                                    color: const Color(0xFF333333),
                                    onTap: () async {
                                      // TODO: Implement GitHub OAuth
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'GitHub login coming soon!',
                                            style: GoogleFonts.outfit(),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),

                            // Sign up link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Don't have an account? ",
                                  style: GoogleFonts.outfit(
                                    color: AppTheme.textSecondary,
                                    fontSize: 15,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const SignupScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'Sign Up',
                                    style: GoogleFonts.outfit(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.border.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundEffects() {
    return const SizedBox();
  }

  Widget _buildLogo() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.primary.withValues(alpha: 0.1),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.3),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(
          Icons.bolt_rounded,
          size: 56,
          color: AppTheme.primary,
        ),
      ),
    );
  }

  Widget _buildLoginButton(bool isLoading) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : _handleLogin,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: AppTheme.background,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      'Login',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.background,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
