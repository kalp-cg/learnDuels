import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/nav_provider.dart';
import '../../providers/user_provider.dart';
import '../../core/theme.dart';
import 'dart:async';
import '../../providers/notification_provider.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/animated_widgets.dart';

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
  bool get wantKeepAlive => true; // Keep state alive when switching tabs

  @override
  void initState() {
    super.initState();
    // Only refresh every 60 seconds to reduce lag
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
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      body: Container(
        color: AppTheme.background,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(userProfileProvider);
              ref.invalidate(userStatsProvider);
              ref.invalidate(globalLeaderboardProvider);
            },
            color: AppTheme.primary,
            backgroundColor: AppTheme.surface,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              cacheExtent: 500, // Preload more content for smooth scroll
              physics:
                  const BouncingScrollPhysics(), // Smooth iOS-like scrolling
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                Consumer(
                  builder: (context, ref, _) {
                    final userAsync = ref.watch(userProfileProvider);
                    final statsAsync = ref.watch(userStatsProvider);
                    return userAsync.when(
                      data: (user) => _buildUserCard(user, statsAsync),
                      loading: () => _buildLoadingCard(),
                      error: (e, s) => const SizedBox(),
                    );
                  },
                ),
                const SizedBox(height: 40),
                _buildSectionHeader('Quick Actions'),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: AnimatedActionButton(
                        text: 'Start Duel',
                        icon: Icons.bolt_rounded,
                        color: AppTheme.primary,
                        onTap: () => Navigator.pushNamed(context, '/topics'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AnimatedActionButton(
                        text: 'Practice',
                        icon: Icons.psychology_rounded,
                        color: AppTheme.accent,
                        onTap: () => Navigator.pushNamed(context, '/practice'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AnimatedActionButton(
                        text: 'Challenge',
                        icon: Icons.groups_rounded,
                        color: AppTheme.secondary,
                        onTap: () =>
                            Navigator.pushNamed(context, '/challenges'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AnimatedActionButton(
                        text: 'Contribute',
                        icon: Icons.edit_note_rounded,
                        color: AppTheme.tertiary,
                        onTap: () =>
                            Navigator.pushNamed(context, '/create-question'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AnimatedActionButton(
                        text: 'Watch Live',
                        icon: Icons.live_tv_rounded,
                        color: Colors.redAccent,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SpectatorListScreen(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Spacer(), // Placeholder for future button
                  ],
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionHeader('Top Players'),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextButton(
                        onPressed: () {
                          ref.read(bottomNavIndexProvider.notifier).state = 1;
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Row(
                          children: [
                            Text(
                              'View All',
                              style: GoogleFonts.firaCode(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: AppTheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Consumer(
                  builder: (context, ref, _) {
                    final topPlayers = ref.watch(globalLeaderboardProvider);
                    return topPlayers.when(
                      data: (players) => Column(
                        children: players
                            .take(5)
                            .map(
                              (p) =>
                                  _buildPlayerItem(p, players.indexOf(p) + 1),
                            )
                            .toList(),
                      ),
                      loading: () => const ShimmerPlayerList(itemCount: 5),
                      error: (e, s) => const SizedBox(),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.firaCode(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo
              Text(
                'LearnDuels',
                style: GoogleFonts.firaCode(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                  letterSpacing: -0.5,
                ),
              ),
              Row(
                children: [
                  Consumer(
                    builder: (context, ref, _) {
                      final unreadCount = ref.watch(
                        unreadNotificationCountProvider,
                      );

                      return _buildIconButton(
                        Icons.notifications_outlined,
                        unreadCount > 0 ? unreadCount : null,
                        () {
                          ref
                                  .read(
                                    unreadNotificationCountProvider.notifier,
                                  )
                                  .state =
                              0;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationScreen(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildIconButton(Icons.logout_rounded, null, () {
                    ref.read(authStateProvider.notifier).logout();
                    Navigator.pushReplacementNamed(context, '/login');
                  }),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Personalized greeting
          Consumer(
            builder: (context, ref, _) {
              final userAsync = ref.watch(userProfileProvider);
              return userAsync.when(
                data: (user) {
                  final username = user?['username'] ?? 'Champion';
                  final streak = user?['streak'] ?? 0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${getTimeBasedGreeting()}, $username! 👋',
                        style: GoogleFonts.firaCode(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            'Ready to dominate?',
                            style: GoogleFonts.firaCode(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                          if (streak > 0) ...[
                            const SizedBox(width: 12),
                            StreakBadge(streak: streak),
                          ],
                        ],
                      ),
                    ],
                  );
                },
                loading: () => Text(
                  '${getTimeBasedGreeting()}! 👋',
                  style: GoogleFonts.firaCode(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                error: (_, __) => Text(
                  '${getTimeBasedGreeting()}! 👋',
                  style: GoogleFonts.firaCode(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          // Gradient button
          Container(
            width: double.infinity,
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
                onTap: () => Navigator.pushNamed(context, '/topics'),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        color: AppTheme.background,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Start New Duel',
                        style: GoogleFonts.firaCode(
                          color: AppTheme.background,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: -0.2,
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
  }

  Widget _buildIconButton(IconData icon, int? badge, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.border.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Badge(
              isLabelVisible: badge != null,
              label: badge != null ? Text('$badge') : null,
              backgroundColor: AppTheme.secondary,
              child: Icon(icon, color: AppTheme.textPrimary, size: 22),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(
    Map<String, dynamic>? user,
    AsyncValue<Map<String, dynamic>?> statsAsync,
  ) {
    if (user == null) return const SizedBox();

    final username = user['username'] ?? 'Player';
    final level = user['level'] ?? 1;
    final xp = user['xp'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: AppTheme.glassDecoration(borderRadius: 24),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar with gradient border
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(19),
                    child:
                        user['avatarUrl'] != null &&
                            user['avatarUrl'].toString().isNotEmpty
                        ? Image.network(
                            user['avatarUrl'],
                            fit: BoxFit.cover,
                            width: 68,
                            height: 68,
                            errorBuilder: (_, _, _) => Center(
                              child: Text(
                                username[0].toUpperCase(),
                                style: GoogleFonts.firaCode(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              username[0].toUpperCase(),
                              style: GoogleFonts.firaCode(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: GoogleFonts.firaCode(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Level badge with glow
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'Level $level • $xp XP',
                        style: GoogleFonts.firaCode(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          // Stats row with dividers
          statsAsync.when(
            data: (stats) {
              final wins = stats?['wins'] ?? 0;
              final total = stats?['totalDuels'] ?? 0;
              final rate = total > 0 ? (wins / total * 100).toInt() : 0;
              return Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppTheme.border.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Wins',
                        wins.toString(),
                        Icons.emoji_events_rounded,
                        AppTheme.tertiary,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 50,
                      color: AppTheme.border.withValues(alpha: 0.3),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Win Rate',
                        '$rate%',
                        Icons.pie_chart_rounded,
                        AppTheme.primary,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 50,
                      color: AppTheme.border.withValues(alpha: 0.3),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Rep',
                        user['reputation'].toString(),
                        Icons.star_rounded,
                        AppTheme.secondary,
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  color: AppTheme.primary,
                  strokeWidth: 2,
                ),
              ),
            ),
            error: (e, s) => Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppTheme.border.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'Wins',
                      '0',
                      Icons.emoji_events_rounded,
                      AppTheme.tertiary,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Rate',
                      '0%',
                      Icons.pie_chart_rounded,
                      AppTheme.primary,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Rep',
                      '0',
                      Icons.star_rounded,
                      AppTheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: GoogleFonts.firaCode(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.firaCode(
            fontSize: 13,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerItem(Map<String, dynamic> player, int rank) {
    final username = player['username'] ?? 'Player';
    final xp = player['xp'] ?? 0;

    // Rank colors
    Color rankColor;
    if (rank == 1) {
      rankColor = AppTheme.gold;
    } else if (rank == 2) {
      rankColor = AppTheme.silver;
    } else if (rank == 3) {
      rankColor = AppTheme.bronze;
    } else {
      rankColor = AppTheme.textMuted;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: rank <= 3
              ? rankColor.withValues(alpha: 0.3)
              : AppTheme.border.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: rank <= 3
                ? rankColor.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Animated rank badge with medals for top 3
          PulsingRankBadge(rank: rank, color: rankColor),
          const SizedBox(width: 16),
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: rank <= 3
                  ? rankColor.withValues(alpha: 0.2)
                  : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child:
                  player['avatarUrl'] != null &&
                      player['avatarUrl'].toString().isNotEmpty
                  ? Image.network(
                      player['avatarUrl'],
                      fit: BoxFit.cover,
                      width: 48,
                      height: 48,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          username[0].toUpperCase(),
                          style: GoogleFonts.firaCode(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: rank <= 3 ? rankColor : AppTheme.primary,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        username[0].toUpperCase(),
                        style: GoogleFonts.firaCode(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: rank <= 3 ? rankColor : AppTheme.primary,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              username,
              style: GoogleFonts.firaCode(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          // XP badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$xp XP',
              style: GoogleFonts.firaCode(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return const ShimmerUserCard();
  }
}
