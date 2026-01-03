import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../core/services/socket_service.dart';

import '../duel/topic_selection_screen.dart';
import 'edit_profile_screen.dart';
import '../friends/friends_screen.dart';
import 'saved_questions_screen.dart';
import 'my_contributions_screen.dart';
import 'dart:async';

class ProfileScreen extends ConsumerStatefulWidget {
  final int? userId; // If null, shows current user's profile

  const ProfileScreen({super.key, this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  Timer? _refreshTimer;
  late Function(dynamic) _notificationHandler;

  @override
  bool get wantKeepAlive => true; // Keep state when switching tabs

  bool get isCurrentUser => widget.userId == null;

  @override
  void initState() {
    super.initState();
    // Reduced from 30s to 120s for smoother performance
    _refreshTimer = Timer.periodic(const Duration(seconds: 120), (_) {
      if (mounted) {
        _refreshData();
      }
    });

    _notificationHandler = (data) {
      if (data['type'] == 'follow_accepted' ||
          data['type'] == 'follow_declined') {
        if (mounted) {
          // If viewing the profile of the person who accepted/declined
          if (!isCurrentUser && widget.userId == data['userId']) {
            _refreshData();
          }
          // If viewing own profile, following count changed (only for accepted)
          if (isCurrentUser && data['type'] == 'follow_accepted') {
            _refreshData();
          }
        }
      }
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupSocketListeners();
    });
  }

  void _setupSocketListeners() {
    final socketService = ref.read(socketServiceProvider);
    socketService.on('notification', _notificationHandler);
  }

  void _refreshData() {
    if (isCurrentUser) {
      ref.invalidate(userProfileProvider);
      ref.invalidate(userStatsProvider);
    } else {
      ref.invalidate(otherUserProfileProvider(widget.userId!));
      // ref.invalidate(otherUserStatsProvider(widget.userId!)); // If we implement this later
    }
  }

  @override
  void dispose() {
    final socketService = ref.read(socketServiceProvider);
    socketService.off('notification', _notificationHandler);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final profileAsync = isCurrentUser
        ? ref.watch(userProfileProvider)
        : ref.watch(otherUserProfileProvider(widget.userId!));

    final statsAsync = isCurrentUser
        ? ref.watch(userStatsProvider)
        : const AsyncValue.data(null); // No detailed stats for others yet

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _refreshData(),
          color: Theme.of(context).colorScheme.primary,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              profileAsync.when(
                data: (profile) => _buildProfileSection(profile, statsAsync),
                loading: () => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                error: (err, stack) => Center(
                  child: Text(
                    'Error loading profile',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (isCurrentUser) ...[
                statsAsync.when(
                  data: (stats) => _buildStatsSection(stats),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
                const SizedBox(height: 32),
                Text(
                  'Actions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 16),
                _buildActionItem('Friends', Icons.people_rounded, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FriendsScreen(),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _buildActionItem('My Vault', Icons.bookmark_rounded, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SavedQuestionsScreen(),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _buildActionItem('My Contributions', Icons.quiz_rounded, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MyContributionsScreen(),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _buildActionItem('Edit Profile', Icons.edit_rounded, () {
                  final profile = profileAsync.value;
                  if (profile != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            EditProfileScreen(currentProfile: profile),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please wait for profile to load'),
                      ),
                    );
                  }
                }),
                const SizedBox(height: 8),
                _buildActionItem('Logout', Icons.logout_rounded, () {
                  ref.read(authStateProvider.notifier).logout();
                  Navigator.pushReplacementNamed(context, '/login');
                }, isDestructive: true),
              ] else ...[
                // Actions for other users
                const SizedBox(height: 32),
                Text(
                  'Actions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 16),
                _buildActionItem('Challenge to Duel', Icons.sports_esports, () {
                  final profile = profileAsync.value;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TopicSelectionScreen(
                        opponentId: widget.userId!,
                        opponentName: profile?['fullName'] ?? 'Opponent',
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        if (!isCurrentUser)
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(
              Icons.arrow_back_ios,
              color: Theme.of(context).iconTheme.color,
              size: 24,
            ),
          ),
        if (!isCurrentUser) const SizedBox(width: 8),
        Text(
          isCurrentUser ? 'My Profile' : 'Profile',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const Spacer(),
        if (isCurrentUser) ...[
          IconButton(
            onPressed: () async {
              await Navigator.pushNamed(context, '/follow-requests');
              // Refresh profile data when returning (to update follower counts etc)
              _refreshData();
            },
            icon: Icon(
              Icons.person_add_rounded,
              color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.7),
            ),
            tooltip: 'Follow Requests',
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.settings_rounded,
              color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProfileSection(
    Map<String, dynamic>? profile,
    AsyncValue<Map<String, dynamic>?> statsAsync,
  ) {
    if (profile == null) return const SizedBox();

    final username = profile['username'] ?? 'Player';
    final fullName = profile['fullName'];
    final email = profile['email'] ?? '';
    final level = profile['level'] ?? 1;
    final xp = profile['xp'] ?? 0;
    final reputation = profile['reputation'] ?? 0;
    final avatarUrl = profile['avatarUrl'];
    final bio = profile['bio'];
    final currentStreak = profile['currentStreak'] ?? 0;
    final longestStreak = profile['longestStreak'] ?? 0;

    return Column(
      children: [
        // Streak Card
        if (isCurrentUser) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF9800), // Orange
                  const Color(0xFFFF5722), // Deep Orange
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF5722).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_fire_department_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$currentStreak Day Streak!',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Longest: $longestStreak days',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: ClipOval(
            child: (avatarUrl != null && avatarUrl.isNotEmpty)
                ? Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    width: 100,
                    height: 100,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        username.isNotEmpty ? username[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      username.isNotEmpty ? username[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          fullName ?? username,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        if (fullName != null) ...[
          const SizedBox(height: 4),
          Text(
            '@$username',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
        const SizedBox(height: 6),
        if (isCurrentUser)
          Text(
            email,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w400),
          ),
        if (bio != null && bio.toString().isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              bio,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBadge('Lvl $level', Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            _buildBadge('$xp XP', Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            _buildBadge(
              '$reputation Rep',
              Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStatCount('Solved', profile['questionsSolved'] ?? 0),
            const SizedBox(width: 24),
            _buildStatCount('Quizzes', profile['quizzesCompleted'] ?? 0),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCount(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatsSection(Map<String, dynamic>? stats) {
    if (stats == null) return const SizedBox();

    final wins = stats['wins'] ?? 0;
    final losses = stats['losses'] ?? 0;
    // final draws = stats['draws'] ?? 0;
    final totalDuels = stats['totalDuels'] ?? 0;
    final winRate = totalDuels > 0 ? (wins / totalDuels * 100).toInt() : 0;

    final correctAnswers = stats['correctAnswers'] ?? 0;
    final totalAnswers = stats['totalAnswers'] ?? 0;
    final wrongAnswers = stats['wrongAnswers'] ?? 0;
    final accuracy = totalAnswers > 0
        ? (correctAnswers / totalAnswers * 100).toInt()
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistics',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Duel Stats',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildStatItem('Wins', wins.toString())),
                  Container(
                    width: 1,
                    height: 40,
                    color: Theme.of(context).dividerColor,
                  ),
                  Expanded(child: _buildStatItem('Losses', losses.toString())),
                  Container(
                    width: 1,
                    height: 40,
                    color: Theme.of(context).dividerColor,
                  ),
                  Expanded(child: _buildStatItem('Win Rate', '$winRate%')),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Question Stats',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem('Correct', correctAnswers.toString()),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Theme.of(context).dividerColor,
                  ),
                  Expanded(
                    child: _buildStatItem('Wrong', wrongAnswers.toString()),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _buildStatItem('Accuracy', '$accuracy%')),
                  Container(
                    width: 1,
                    height: 40,
                    color: Theme.of(context).dividerColor,
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Total Attempted',
                      totalAnswers.toString(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildActionItem(
    String text,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDestructive
                ? Theme.of(context).colorScheme.error.withValues(alpha: 0.2)
                : Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive
                  ? Theme.of(context).colorScheme.error.withValues(alpha: 0.8)
                  : Theme.of(context).iconTheme.color?.withValues(alpha: 0.7),
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isDestructive
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDestructive
                  ? Theme.of(context).colorScheme.error.withValues(alpha: 0.5)
                  : Theme.of(context).iconTheme.color?.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
