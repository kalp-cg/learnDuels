import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  bool _obscurePassword = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
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
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(authStateProvider.notifier)
        .login(_emailController.text.trim(), _passwordController.text);

    if (!mounted || !success) return;

    // Use full stack replacement so back cannot bounce to login unexpectedly.
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  Future<void> _handleGoogleSignIn() async {
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
        if (e.toString().contains("10")) {
          googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
          account = await googleSignIn.signIn();
        } else {
          rethrow;
        }
      }

      if (account == null) return;

      final auth = await account.authentication;
      final idToken = auth.idToken;
      final accessToken = auth.accessToken;

      if (idToken == null || accessToken == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Token acquisition failed.',
              style: AppTheme.mono(fontSize: 13),
            ),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }

      if (!mounted) return;
      final success = await ref
          .read(authStateProvider.notifier)
          .loginWithGoogle(idToken, accessToken);
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OAuth error: $e', style: AppTheme.mono(fontSize: 12)),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isLoading = authState is AsyncLoading;
    final authError = authState is AsyncError
        ? authState.error.toString()
        : null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo icon
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: const Icon(
                        Icons.terminal_rounded,
                        size: 32,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // App name
                    Text(
                      'LEARN_DULES',
                      style: GoogleFonts.firaCode(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Competitive CS Learning Protocol',
                      style: AppTheme.body(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Feature badges
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AppTheme.featureBadge(
                          '1v1_DUELS',
                          icon: Icons.bolt_rounded,
                          color: AppTheme.primary,
                        ),
                        AppTheme.featureBadge(
                          'DSA_TRACKS',
                          icon: Icons.code_rounded,
                          color: AppTheme.textSecondary,
                        ),
                        AppTheme.featureBadge(
                          'ELO_RATING',
                          icon: Icons.trending_up_rounded,
                          color: AppTheme.secondary,
                        ),
                        AppTheme.featureBadge(
                          'SOCIAL_FEED',
                          icon: Icons.people_rounded,
                          color: AppTheme.tertiary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),

                    // Auth section label
                    Text(
                      'AUTHENTICATION',
                      style: GoogleFonts.firaCode(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.secondary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Email field
                    Text(
                      'EMAIL_ADDRESS',
                      style: GoogleFonts.firaCode(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: AppTheme.body(
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'user@terminal.io',
                        hintStyle: AppTheme.body(
                          fontSize: 14,
                          color: AppTheme.textMuted,
                        ),
                        filled: true,
                        fillColor: AppTheme.surfaceLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppTheme.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required field';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Password field
                    Text(
                      'ACCESS_KEY',
                      style: GoogleFonts.firaCode(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: AppTheme.body(
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        hintStyle: AppTheme.body(
                          fontSize: 14,
                          color: AppTheme.textMuted,
                        ),
                        filled: true,
                        fillColor: AppTheme.surfaceLight,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppTheme.textMuted,
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppTheme.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required field';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

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
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                        ),
                        child: Text(
                          'FORGOT_ACCESS_KEY?',
                          style: GoogleFonts.firaCode(
                            fontSize: 11,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Login button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.background,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isLoading) ...[
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.background,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Text(
                              isLoading
                                  ? 'AUTHENTICATING...'
                                  : 'INITIALIZE_SESSION',
                              style: GoogleFonts.firaCode(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: AppTheme.background,
                              ),
                            ),
                            if (!isLoading) ...[
                              const SizedBox(width: 10),
                              const Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (authError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.error),
                        ),
                        child: Text(
                          authError,
                          style: AppTheme.mono(
                            fontSize: 12,
                            color: AppTheme.error,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),

                    // Divider
                    Row(
                      children: [
                        Expanded(
                          child: Container(height: 1, color: AppTheme.border),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR_USE_OAUTH',
                            style: GoogleFonts.firaCode(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(height: 1, color: AppTheme.border),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Google button
                    _buildOAuthButton(
                      icon: Icons.g_mobiledata_rounded,
                      label: 'Continue with Google',
                      onTap: _handleGoogleSignIn,
                    ),
                    const SizedBox(height: 12),

                    // GitHub button
                    _buildOAuthButton(
                      icon: Icons.code_rounded,
                      label: 'Continue with GitHub',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'GitHub OAuth coming soon',
                              style: AppTheme.mono(fontSize: 13),
                            ),
                            backgroundColor: AppTheme.surface,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),

                    // Sign up link
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'NEW_USER?  ',
                            style: GoogleFonts.firaCode(
                              fontSize: 13,
                              color: AppTheme.textMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SignupScreen(),
                              ),
                            ),
                            child: Text(
                              'CREATE_ACCOUNT',
                              style: GoogleFonts.firaCode(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Status badge
                    Center(
                      child: AppTheme.statusBadge(
                        'ENCRYPTED_SESSION_ACTIVE',
                        color: AppTheme.success,
                        icon: Icons.shield_outlined,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'v2.0.4-stable // system_ready',
                        style: GoogleFonts.firaCode(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOAuthButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.border),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: AppTheme.surfaceLight,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: AppTheme.textPrimary),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppTheme.body(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
