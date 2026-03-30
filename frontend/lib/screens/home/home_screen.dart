import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/nav_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/notification_provider.dart';
import '../notifications/notification_screen.dart';
import '../spectator/spectator_list_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  Timer? _refreshTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) {
        ref.invalidate(userProfileProvider);
        ref.invalidate(userStatsProvider);
        ref.invalidate(globalLeaderboardProvider);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(userProfileProvider);
            ref.invalidate(userStatsProvider);
            ref.invalidate(globalLeaderboardProvider);
          },
          color: AppTheme.primary,
          backgroundColor: AppTheme.surface,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              _buildTopBar(),
              _buildHeroSection(),
              _buildStatsRow(),
              const SizedBox(height: 28),
              _buildSectionLabel('QUICK_ACTIONS'),
              const SizedBox(height: 12),
              _buildActionsGrid(),
              const SizedBox(height: 28),
              _buildDailyChallengeCard(),
              const SizedBox(height: 28),
              _buildSectionLabel(
                'TOP_PLAYERS',
                trailing: TextButton(
                  onPressed: () =>
                      ref.read(bottomNavIndexProvider.notifier).state = 1,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'VIEW_ALL →',
                    style: GoogleFonts.firaCode(
                      fontSize: 11,
                      color: AppTheme.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildLeaderboardList(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ─── TOP BAR ──────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
      child: Row(
        children: [
          Text(
            'LEARN_DULES',
            style: GoogleFonts.firaCode(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          Consumer(
            builder: (context, ref, _) {
              final count = ref.watch(unreadNotificationCountProvider);
              return _iconBtn(
                Icons.notifications_outlined,
                badge: count > 0 ? count : null,
                onTap: () {
                  ref.read(unreadNotificationCountProvider.notifier).state = 0;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationScreen(),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(width: 4),
          _iconBtn(
            Icons.power_settings_new_rounded,
            onTap: () {
              ref.read(authStateProvider.notifier).logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }

  // ─── HERO SECTION ─────────────────────────────────────
  Widget _buildHeroSection() {
    return Consumer(
      builder: (context, ref, _) {
        final userAsync = ref.watch(userProfileProvider);
        return userAsync.when(
          data: (user) {
            final username = user?['username'] ?? 'Champion';
            final level = user?['level'] ?? 1;
            final xp = user?['xp'] ?? 0;
            final streak = user?['currentStreak'] ?? 0;
            final avatarUrl = user?['avatarUrl'];
            final initial = username.isNotEmpty
                ? username[0].toUpperCase()
                : '?';

            return Container(
              margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Avatar
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primary,
                            width: 1.5,
                          ),
                          color: AppTheme.surfaceLight,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child:
                              avatarUrl != null &&
                                  avatarUrl.toString().isNotEmpty
                              ? Image.network(
                                  avatarUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (
                                    context,
                                    error,
                                    stackTrace,
                                  ) => Center(
                                    child: Text(
                                      initial,
                                      style: GoogleFonts.firaCode(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    initial,
                                    style: GoogleFonts.firaCode(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_greeting()}, $username',
                              style: GoogleFonts.firaCode(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _pill('LVL $level', AppTheme.primary),
                                const SizedBox(width: 6),
                                _pill('$xp XP', AppTheme.textMuted),
                                if (streak > 0) ...[
                                  const SizedBox(width: 6),
                                  _pill('🔥 $streak', AppTheme.tertiary),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Primary CTA
                  SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => Navigator.pushNamed(context, '/topics'),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.bolt_rounded,
                                color: AppTheme.background,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'START_DUEL',
                                style: GoogleFonts.firaCode(
                                  color: AppTheme.background,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => _heroSkeleton(),
          error: (error, stackTrace) => const SizedBox.shrink(),
        );
      },
    );
  }

  // ─── STATS ROW ────────────────────────────────────────
  Widget _buildStatsRow() {
    return Consumer(
      builder: (context, ref, _) {
        final statsAsync = ref.watch(userStatsProvider);
        return statsAsync.when(
          data: (stats) {
            final wins = stats?['wins'] ?? 0;
            final total = stats?['totalDuels'] ?? 0;
            final rate = total > 0 ? (wins / total * 100).toInt() : 0;
            final rank = stats?['rank'] ?? '—';

            return Container(
              margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  _statCell(
                    'DUELS',
                    '$total',
                    Icons.sports_esports_rounded,
                    AppTheme.primary,
                  ),
                  _divider(),
                  _statCell(
                    'WINS',
                    '$wins',
                    Icons.emoji_events_rounded,
                    AppTheme.secondary,
                  ),
                  _divider(),
                  _statCell(
                    'WIN %',
                    '$rate%',
                    Icons.pie_chart_rounded,
                    AppTheme.tertiary,
                  ),
                  _divider(),
                  _statCell(
                    'RANK',
                    '#$rank',
                    Icons.leaderboard_rounded,
                    AppTheme.accent,
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox(height: 65),
          error: (error, stackTrace) => const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _statCell(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 5),
          Text(
            value,
            style: GoogleFonts.firaCode(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.firaCode(
              fontSize: 9,
              color: AppTheme.textMuted,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 40, color: AppTheme.border);

  // ─── ACTIONS GRID ─────────────────────────────────────
  Widget _buildActionsGrid() {
    final actions = [
      _ActionItem(
        'DUEL',
        Icons.bolt_rounded,
        AppTheme.primary,
        () => Navigator.pushNamed(context, '/topics'),
      ),
      _ActionItem(
        'PRACTICE',
        Icons.psychology_rounded,
        AppTheme.accent,
        () => Navigator.pushNamed(context, '/practice'),
      ),
      _ActionItem(
        'CHALLENGE',
        Icons.groups_rounded,
        AppTheme.secondary,
        () => Navigator.pushNamed(context, '/challenges'),
      ),
      _ActionItem(
        'CONTRIBUTE',
        Icons.edit_note_rounded,
        AppTheme.tertiary,
        () => Navigator.pushNamed(context, '/create-question'),
      ),
      _ActionItem('WATCH LIVE', Icons.live_tv_rounded, Colors.redAccent, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SpectatorListScreen()),
        );
      }),
      _ActionItem(
        'RANKINGS',
        Icons.leaderboard_rounded,
        AppTheme.gold,
        () => ref.read(bottomNavIndexProvider.notifier).state = 1,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.05,
        children: actions.map(_buildActionCard).toList(),
      ),
    );
  }

  Widget _buildActionCard(_ActionItem action) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: action.color.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(action.icon, color: action.color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                action.label,
                textAlign: TextAlign.center,
                style: GoogleFonts.firaCode(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── DAILY CHALLENGE CARD ─────────────────────────────
  Widget _buildDailyChallengeCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                color: AppTheme.secondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DAILY_CHALLENGE',
                    style: GoogleFonts.firaCode(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.secondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Complete today\'s challenge for bonus XP',
                    style: AppTheme.body(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Material(
              color: AppTheme.secondary,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () => Navigator.pushNamed(context, '/practice'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  child: Text(
                    'GO',
                    style: GoogleFonts.firaCode(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.background,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── LEADERBOARD LIST ─────────────────────────────────
  Widget _buildLeaderboardList() {
    return Consumer(
      builder: (context, ref, _) {
        final topPlayers = ref.watch(globalLeaderboardProvider);
        return topPlayers.when(
          data: (players) => Column(
            children: players
                .take(5)
                .toList()
                .asMap()
                .entries
                .map((e) => _buildPlayerRow(e.value, e.key + 1))
                .toList(),
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: CircularProgressIndicator(
                color: AppTheme.primary,
                strokeWidth: 2,
              ),
            ),
          ),
          error: (error, stackTrace) => const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildPlayerRow(Map<String, dynamic> player, int rank) {
    final username = player['username'] ?? 'Player';
    final xp = player['xp'] ?? 0;
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    final rankColor = rank == 1
        ? AppTheme.gold
        : rank == 2
        ? AppTheme.silver
        : rank == 3
        ? AppTheme.bronze
        : AppTheme.textMuted;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: rank <= 3 ? rankColor.withValues(alpha: 0.3) : AppTheme.border,
          width: rank <= 3 ? 1.0 : 0.5,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: rank <= 3
                ? Text(
                    rank == 1
                        ? '🥇'
                        : rank == 2
                        ? '🥈'
                        : '🥉',
                    style: const TextStyle(fontSize: 18),
                  )
                : Text(
                    '#$rank',
                    style: GoogleFonts.firaCode(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.surfaceLight,
            backgroundImage:
                (player['avatarUrl'] != null &&
                    player['avatarUrl'].toString().isNotEmpty)
                ? NetworkImage(player['avatarUrl'])
                : null,
            child:
                (player['avatarUrl'] == null ||
                    player['avatarUrl'].toString().isEmpty)
                ? Text(
                    initial,
                    style: GoogleFonts.firaCode(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: rank <= 3 ? rankColor : AppTheme.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              username,
              style: GoogleFonts.firaCode(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              '$xp XP',
              style: GoogleFonts.firaCode(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SHARED HELPERS ───────────────────────────────────
  Widget _buildSectionLabel(String label, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            color: AppTheme.primary,
            margin: const EdgeInsets.only(right: 8),
          ),
          Text(
            label,
            style: GoogleFonts.firaCode(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, {int? badge, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Badge(
            isLabelVisible: badge != null,
            label: badge != null
                ? Text('$badge', style: const TextStyle(fontSize: 9))
                : null,
            backgroundColor: AppTheme.secondary,
            child: Icon(icon, color: AppTheme.textSecondary, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: GoogleFonts.firaCode(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _heroSkeleton() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      height: 155,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: AppTheme.primary,
          strokeWidth: 2,
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'GM';
    if (h < 17) return 'GD';
    return 'GE';
  }
}

class _ActionItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionItem(this.label, this.icon, this.color, this.onTap);
}
