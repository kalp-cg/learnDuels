import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/services/leaderboard_service.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  List<Map<String, dynamic>> _entries = [];
  Map<String, dynamic>? _myRank;
  bool _isLoading = true;
  String _activeTab = 'Global XP';
  final List<String> _tabs = [
    'Global XP',
    'DSA',
    'Web Dev',
    'Elo Rating',
    'Streak',
  ];

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);
    try {
      final leaderboardService = ref.read(leaderboardServiceProvider);
      final data = await leaderboardService.getGlobalLeaderboard(
        period: _activeTab == 'Global XP'
            ? 'weekly'
            : _activeTab == 'DSA'
            ? 'weekly'
            : _activeTab == 'Web Dev'
            ? 'weekly'
            : _activeTab == 'Elo Rating'
            ? 'weekly'
            : 'weekly',
      );
      final myRankData = await leaderboardService.getUserRanking();
      if (mounted) {
        setState(() {
          _entries = List<Map<String, dynamic>>.from(data?['data'] ?? []);
          _myRank = myRankData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LEADERBOARD',
                        style: GoogleFonts.firaCode(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Global Rankings • Updated 5m ago',
                        style: AppTheme.body(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: _loadLeaderboard,
                    icon: const Icon(
                      Icons.tune_rounded,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab bar
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _tabs.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final tab = _tabs[index];
                  final isActive = tab == _activeTab;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _activeTab = tab);
                      _loadLeaderboard();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppTheme.textPrimary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive
                              ? AppTheme.textPrimary
                              : AppTheme.border,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          tab,
                          style: GoogleFonts.firaCode(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isActive
                                ? AppTheme.background
                                : AppTheme.textMuted,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadLeaderboard,
                      color: AppTheme.primary,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          // Top 3 Podium
                          if (_entries.length >= 3) _buildPodium(),
                          const SizedBox(height: 20),

                          // Ranking header
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'RANKING',
                                  style: GoogleFonts.firaCode(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textMuted,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                Text(
                                  'TOTAL EXPERIENCE',
                                  style: GoogleFonts.firaCode(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textMuted,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Entries (skip top 3 since they're on podium)
                          ...(_entries.length > 3
                                  ? _entries.sublist(3)
                                  : _entries)
                              .asMap()
                              .entries
                              .map((entry) {
                                final index = _entries.length > 3
                                    ? entry.key + 4
                                    : entry.key + 1;
                                return _buildRankEntry(entry.value, index);
                              }),
                        ],
                      ),
                    ),
            ),

            // My rank pinned at bottom
            if (_myRank != null) _buildMyRankBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildPodium() {
    if (_entries.length < 3) return const SizedBox();
    final first = _entries[0];
    final second = _entries[1];
    final third = _entries[2];

    return SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place
          Expanded(child: _buildPodiumCard(second, 2, 150)),
          const SizedBox(width: 10),
          // 1st place
          Expanded(child: _buildPodiumCard(first, 1, 200)),
          const SizedBox(width: 10),
          // 3rd place
          Expanded(child: _buildPodiumCard(third, 3, 130)),
        ],
      ),
    );
  }

  Widget _buildPodiumCard(Map<String, dynamic> user, int rank, double height) {
    final username = user['username'] ?? user['fullName'] ?? 'User';
    final xp = user['xp'] ?? user['score'] ?? 0;
    final avatarUrl = user['avatarUrl'];
    final initials = username.length >= 2
        ? username.substring(0, 2).toUpperCase()
        : username.toUpperCase();

    Color rankColor;
    switch (rank) {
      case 1:
        rankColor = AppTheme.primary;
        break;
      case 2:
        rankColor = AppTheme.textSecondary;
        break;
      default:
        rankColor = AppTheme.textMuted;
        break;
    }

    return Container(
      height: height,
      decoration: AppTheme.terminalCard(
        borderRadius: 14,
        borderColor: rank == 1 ? AppTheme.primary.withValues(alpha: 0.3) : null,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar
          Stack(
            alignment: Alignment.topRight,
            children: [
              CircleAvatar(
                radius: rank == 1 ? 32 : 26,
                backgroundColor: rankColor.withValues(alpha: 0.2),
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl == null
                    ? Text(
                        initials,
                        style: GoogleFonts.firaCode(
                          fontSize: rank == 1 ? 18 : 14,
                          fontWeight: FontWeight.w700,
                          color: rankColor,
                        ),
                      )
                    : null,
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: rankColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$rank',
                  style: GoogleFonts.firaCode(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.background,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            username.length > 10 ? '${username.substring(0, 8)}...' : username,
            style: GoogleFonts.firaCode(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${_formatNumber(xp)} XP',
            style: GoogleFonts.firaCode(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: rankColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankEntry(Map<String, dynamic> user, int rank) {
    final username = user['username'] ?? user['fullName'] ?? 'User';
    final xp = user['xp'] ?? user['score'] ?? 0;
    final rating = user['rating'] ?? 0;
    final initials = username.length >= 2
        ? username.substring(0, 2).toUpperCase()
        : username.toUpperCase();
    final isFriend = user['isFriend'] == true;
    final rankChange = user['rankChange'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: Row(
        children: [
          // Rank number
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: GoogleFonts.firaCode(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.surfaceLight,
            backgroundImage: user['avatarUrl'] != null
                ? NetworkImage(user['avatarUrl'])
                : null,
            child: user['avatarUrl'] == null
                ? Text(
                    initials,
                    style: GoogleFonts.firaCode(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Name + stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      username,
                      style: GoogleFonts.firaCode(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (isFriend) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'FRIEND',
                          style: GoogleFonts.firaCode(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.secondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      size: 12,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${user['streak'] ?? 0}',
                      style: GoogleFonts.firaCode(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.settings_rounded,
                      size: 12,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '$rating',
                      style: GoogleFonts.firaCode(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // XP + rank change
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_formatNumber(xp)} XP',
                style: GoogleFonts.firaCode(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
              if (rankChange != 0)
                Text(
                  rankChange > 0 ? '+$rankChange' : '$rankChange',
                  style: GoogleFonts.firaCode(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: rankChange > 0 ? AppTheme.secondary : AppTheme.error,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyRankBar() {
    final rank = _myRank?['rank'] ?? '--';
    final username = _myRank?['username'] ?? 'You';
    final xp = _myRank?['xp'] ?? 0;
    final initials = username.length >= 2
        ? username.substring(0, 2).toUpperCase()
        : 'ME';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Text(
            '$rank',
            style: GoogleFonts.firaCode(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
            child: Text(
              initials,
              style: GoogleFonts.firaCode(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You ($username)',
                  style: GoogleFonts.firaCode(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'Top 5% of all learners',
                  style: AppTheme.body(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_formatNumber(xp)} XP',
                style: GoogleFonts.firaCode(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatNumber(dynamic num) {
    if (num == null) return '0';
    final n = num is int ? num : int.tryParse(num.toString()) ?? 0;
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}
