import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import 'edit_profile_screen.dart';
import 'saved_questions_screen.dart';
import 'my_contributions_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: userAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (e, _) => _buildErrorState(e.toString()),
        data: (user) {
          if (user == null) {
            return _buildErrorState('No user data returned.');
          }
          return _buildProfileContent(user);
        },
      ),
    );
  }

  Widget _buildErrorState(String message) {
    final sessionExpired =
        message.contains('Session expired') ||
        message.contains('Not logged in') ||
        message.contains('token');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              sessionExpired ? Icons.lock_outline : Icons.error_outline,
              color: sessionExpired ? AppTheme.tertiary : AppTheme.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              sessionExpired ? 'SESSION_EXPIRED' : 'LOAD_FAILED',
              style: GoogleFonts.firaCode(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.body(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 24),
            if (!sessionExpired)
              OutlinedButton(
                onPressed: () => ref.invalidate(userProfileProvider),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.primary),
                  foregroundColor: AppTheme.primary,
                ),
                child: Text(
                  'RETRY',
                  style: GoogleFonts.firaCode(fontSize: 12, letterSpacing: 0.5),
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                ref.read(authStateProvider.notifier).logout();
                Navigator.pushReplacementNamed(context, '/login');
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.tertiary),
                foregroundColor: AppTheme.tertiary,
              ),
              child: Text(
                sessionExpired ? 'LOG_IN_AGAIN' : 'LOGOUT',
                style: GoogleFonts.firaCode(fontSize: 12, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent(Map<String, dynamic> user) {
    final username = user['username'] ?? 'user';
    final bio = user['bio'] ?? '';
    final avatarUrl = user['avatarUrl'];
    final level = user['level'] ?? 1;
    final xp = user['xp'] ?? 0;
    final rating = user['rating'] ?? 1200;
    final reputation = user['reputation'] ?? 0;
    final streak = user['currentStreak'] ?? 0;
    final solved = user['questionsSolved'] ?? 0;
    final followers = user['followersCount'] ?? 0;
    final following = user['followingCount'] ?? 0;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(userProfileProvider),
        color: AppTheme.primary,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Profile header
            Row(
              children: [
                // Avatar with level badge
                Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.border, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: avatarUrl != null
                            ? Image.network(
                                avatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (
                                  context,
                                  error,
                                  stackTrace,
                                ) =>
                                    _defaultAvatar(username),
                              )
                            : _defaultAvatar(username),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'LVL $level',
                            style: GoogleFonts.firaCode(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.background,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Username + bio + followers
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            username,
                            style: GoogleFonts.firaCode(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          IconButton(
                            onPressed: () => _showSettingsMenu(context),
                            icon: const Icon(
                              Icons.settings_outlined,
                              color: AppTheme.textSecondary,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                      if (bio.isNotEmpty)
                        Text(
                          bio,
                          style: AppTheme.body(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            _formatCount(followers),
                            style: GoogleFonts.firaCode(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            ' followers  ',
                            style: AppTheme.body(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          Text(
                            _formatCount(following),
                            style: GoogleFonts.firaCode(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            ' following',
                            style: AppTheme.body(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Stats grid
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'REPUTATION',
                    '$reputation',
                    '+12%',
                    AppTheme.secondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatCard(
                    'ELO RATING',
                    '$rating',
                    'TOP 5%',
                    AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard('SOLVED', '$solved', null, null),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatCard('STREAK', '$streak', 'DAYS', null),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // XP Progression chart
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.terminalCard(borderRadius: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'XP PROGRESSION',
                        style: GoogleFonts.firaCode(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.trending_up_rounded,
                              size: 14,
                              color: AppTheme.secondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Weekly +${(xp * 0.1).toInt()} XP',
                              style: GoogleFonts.firaCode(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Chart placeholder
                  SizedBox(
                    height: 120,
                    child: CustomPaint(
                      size: const Size(double.infinity, 120),
                      painter: _XPChartPainter(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                        .map(
                          (d) => Text(
                            d,
                            style: GoogleFonts.firaCode(
                              fontSize: 10,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Topic mastery
            Text(
              'TOPIC MASTERY',
              style: GoogleFonts.firaCode(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMasteryCard(
                    'Data Structures',
                    0.85,
                    AppTheme.secondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMasteryCard(
                    'Algorithms',
                    0.62,
                    AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Recent activity
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RECENT ACTIVITY',
                  style: GoogleFonts.firaCode(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'VIEW LOG',
                  style: GoogleFonts.firaCode(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildActivityItem(
              Icons.emoji_events_rounded,
              AppTheme.secondary,
              'Won Duel vs. opponent',
              'Topic: Graph Theory • +25 ELO',
              '2m ago',
            ),
            _buildActivityItem(
              Icons.check_circle_outline,
              AppTheme.textSecondary,
              'Completed Daily Challenge',
              'Arrays & Hashing • +50 XP',
              '4h ago',
            ),
            _buildActivityItem(
              Icons.arrow_upward_rounded,
              AppTheme.primary,
              'Leveled Up to $level',
              'Milestone reached',
              '1d ago',
            ),
            _buildActivityItem(
              Icons.person_add_rounded,
              AppTheme.warning,
              'New Follower',
              'Someone started following you',
              '2d ago',
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _defaultAvatar(String username) {
    return Container(
      color: AppTheme.surfaceLight,
      alignment: Alignment.center,
      child: Text(
        username.length >= 2
            ? username.substring(0, 2).toUpperCase()
            : username.toUpperCase(),
        style: GoogleFonts.firaCode(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    String? badge,
    Color? badgeColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.terminalCard(borderRadius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.firaCode(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppTheme.textMuted,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.firaCode(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Text(
                  badge,
                  style: GoogleFonts.firaCode(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: badgeColor ?? AppTheme.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMasteryCard(String topic, double progress, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.terminalCard(borderRadius: 12),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  backgroundColor: AppTheme.border,
                  color: color,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                topic,
                style: GoogleFonts.firaCode(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: GoogleFonts.firaCode(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    IconData icon,
    Color color,
    String title,
    String subtitle,
    String time,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: AppTheme.terminalCard(borderRadius: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.firaCode(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: GoogleFonts.firaCode(
              fontSize: 11,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsMenu(BuildContext context) {
    final userAsync = ref.read(userProfileProvider);
    final user = userAsync.value;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _settingsItem(Icons.edit_outlined, 'Edit Profile', () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(currentProfile: user ?? {}),
                ),
              );
            }),
            _settingsItem(Icons.bookmark_outline, 'Saved Questions', () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavedQuestionsScreen()),
              );
            }),
            _settingsItem(Icons.code_rounded, 'My Contributions', () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MyContributionsScreen(),
                ),
              );
            }),
            _settingsItem(Icons.logout_rounded, 'Logout', () {
              Navigator.pop(context);
              ref.read(authStateProvider.notifier).logout();
              Navigator.of(context).pushReplacementNamed('/login');
            }, color: AppTheme.error),
          ],
        ),
      ),
    );
  }

  Widget _settingsItem(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppTheme.textSecondary, size: 22),
      title: Text(
        label,
        style: AppTheme.body(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: color ?? AppTheme.textPrimary,
        ),
      ),
      onTap: onTap,
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }
}

// Simple XP chart painter
class _XPChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final points = [0.3, 0.35, 0.4, 0.55, 0.5, 0.65, 0.75, 0.85];
    final paint = Paint()
      ..color = AppTheme.textPrimary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppTheme.textPrimary.withValues(alpha: 0.1),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTRB(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();
    final spacing = size.width / (points.length - 1);

    for (int i = 0; i < points.length; i++) {
      final x = i * spacing;
      final y = size.height - (points[i] * size.height);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        final prevX = (i - 1) * spacing;
        final prevY = size.height - (points[i - 1] * size.height);
        final cx1 = prevX + spacing * 0.5;
        final cx2 = x - spacing * 0.5;
        path.cubicTo(cx1, prevY, cx2, y, x, y);
        fillPath.cubicTo(cx1, prevY, cx2, y, x, y);
      }
    }

    // Fill
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    // Line
    canvas.drawPath(path, paint);

    // Dots
    final dotPaint = Paint()
      ..color = AppTheme.textPrimary
      ..style = PaintingStyle.fill;
    for (int i = 0; i < points.length; i++) {
      final x = i * spacing;
      final y = size.height - (points[i] * size.height);
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
      canvas.drawCircle(Offset(x, y), 2, Paint()..color = AppTheme.background);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
