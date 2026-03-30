import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/friend_service.dart';
import '../../core/services/socket_service.dart';
import '../../core/theme.dart';
import '../duel/topic_selection_screen.dart';
import '../profile/follow_requests_screen.dart';

// Providers
final friendsProvider = FutureProvider<List<dynamic>>((ref) async {
  final service = ref.watch(friendServiceProvider);
  return service.getFollowing();
});

final allUsersProvider = FutureProvider<List<dynamic>>((ref) async {
  final service = ref.watch(friendServiceProvider);
  return service.getUsers(sortBy: 'newest', limit: 1000);
});

final findFriendsSearchQueryProvider = StateProvider<String>((ref) => '');
final followingInProgressProvider = StateProvider<Set<int>>((ref) => {});

final suggestionsProvider = FutureProvider<List<dynamic>>((ref) async {
  final service = ref.watch(friendServiceProvider);
  try {
    return await service.getRecommendations();
  } catch (e) {
    return await service.getUsers(sortBy: 'popular');
  }
});

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  late Function(dynamic) _notificationHandler;
  SocketService? _socketService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _socketService = ref.read(socketServiceProvider);

    _notificationHandler = (data) {
      if (data['type'] == 'follow_accepted' ||
          data['type'] == 'follow_declined') {
        if (mounted) {
          ref.invalidate(friendsProvider);
          ref.invalidate(allUsersProvider);
          if (data['type'] == 'follow_accepted') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${data['message']}',
                  style: AppTheme.mono(fontSize: 13),
                ),
              ),
            );
          }
        }
      }
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupSocketListeners();
    });
  }

  void _setupSocketListeners() {
    _socketService?.on('notification', _notificationHandler);
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging && mounted) {
      if (_tabController.index == 0) {
        ref.invalidate(friendsProvider);
      } else if (_tabController.index == 1) {
        ref.invalidate(allUsersProvider);
      }
    }
  }

  @override
  void dispose() {
    _socketService?.off('notification', _notificationHandler);
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        ref.read(findFriendsSearchQueryProvider.notifier).state = query;
      }
    });
  }

  Future<void> _followUser(int userId) async {
    ref
        .read(followingInProgressProvider.notifier)
        .update((state) => {...state, userId});
    try {
      await ref.read(friendServiceProvider).followUser(userId);
      ref.invalidate(allUsersProvider);
      ref.invalidate(friendsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Follow request sent',
              style: AppTheme.mono(fontSize: 13, color: AppTheme.success),
            ),
            backgroundColor: AppTheme.surface,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to follow: $e',
              style: AppTheme.mono(fontSize: 12),
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      ref.read(followingInProgressProvider.notifier).update((state) {
        final newState = {...state};
        newState.remove(userId);
        return newState;
      });
    }
  }

  Future<void> _unfollowUser(int userId) async {
    try {
      await ref.read(friendServiceProvider).unfollowUser(userId);
      ref.invalidate(friendsProvider);
      ref.invalidate(allUsersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unfollowed', style: AppTheme.mono(fontSize: 13)),
            backgroundColor: AppTheme.surface,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e', style: AppTheme.mono(fontSize: 12)),
            backgroundColor: AppTheme.error,
          ),
        );
      }
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
                  Text(
                    'Network',
                    style: GoogleFonts.firaCode(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.person_add_outlined,
                          color: AppTheme.textSecondary,
                          size: 22,
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.search_rounded,
                          color: AppTheme.textSecondary,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.primary,
                indicatorWeight: 2,
                labelColor: AppTheme.textPrimary,
                unselectedLabelColor: AppTheme.textMuted,
                labelStyle: GoogleFonts.firaCode(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                unselectedLabelStyle: GoogleFonts.firaCode(
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
                dividerColor: AppTheme.border,
                tabs: const [
                  Tab(text: 'Friends'),
                  Tab(text: 'Discover'),
                  Tab(text: 'Requests'),
                ],
              ),
            ),

            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFriendsList(),
                  _buildFindFriendsList(),
                  const FollowRequestsScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsList() {
    final friendsAsync = ref.watch(friendsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(friendsProvider),
      color: AppTheme.primary,
      child: friendsAsync.when(
        data: (friends) {
          if (friends.isEmpty) return _buildEmptyState();
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: friends.length,
            itemBuilder: (context, index) => _buildFriendCard(friends[index]),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (err, _) =>
            _buildErrorState(() => ref.invalidate(friendsProvider)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border),
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              size: 40,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'NO_CONNECTIONS',
            style: GoogleFonts.firaCode(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Find players to connect with',
            style: AppTheme.body(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => _tabController.animateTo(1),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.primary),
              foregroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'DISCOVER_USERS',
              style: GoogleFonts.firaCode(fontSize: 12, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendCard(Map<String, dynamic> friend) {
    final displayName = friend['fullName'] ?? friend['username'] ?? 'User';
    final username = friend['username'] ?? 'user';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final friendId = friend['id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: Row(
        children: [
          // Avatar with online indicator
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.surfaceLight,
                backgroundImage: friend['avatarUrl'] != null
                    ? NetworkImage(friend['avatarUrl'])
                    : null,
                child: friend['avatarUrl'] == null
                    ? Text(
                        initial,
                        style: GoogleFonts.firaCode(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      )
                    : null,
              ),
              // Online dot
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppTheme.secondary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.background, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: GoogleFonts.firaCode(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@$username',
                  style: AppTheme.body(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),

          // Duel button
          Container(
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TopicSelectionScreen(
                        opponentId: friendId,
                        opponentName: displayName,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        size: 14,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'DUEL',
                        style: GoogleFonts.firaCode(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          PopupMenuButton(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppTheme.textMuted,
              size: 20,
            ),
            color: AppTheme.surface,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'unfollow',
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_remove_rounded,
                      color: AppTheme.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Unfollow',
                      style: AppTheme.body(color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
            onSelected: (value) async {
              if (value == 'unfollow') await _unfollowUser(friendId);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFindFriendsList() {
    final searchQuery = ref.watch(findFriendsSearchQueryProvider);
    final usersAsync = ref.watch(allUsersProvider);
    final followingInProgress = ref.watch(followingInProgressProvider);

    return Column(
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: AppTheme.body(fontSize: 14, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search username...',
              hintStyle: AppTheme.body(fontSize: 14, color: AppTheme.textMuted),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppTheme.textMuted,
                size: 20,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear_rounded,
                        color: AppTheme.textMuted,
                        size: 18,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(allUsersProvider),
            color: AppTheme.primary,
            child: usersAsync.when(
              data: (allUsers) {
                final filtered = searchQuery.isEmpty
                    ? allUsers
                    : allUsers.where((u) {
                        final name = (u['fullName'] ?? '')
                            .toString()
                            .toLowerCase();
                        final uname = (u['username'] ?? '')
                            .toString()
                            .toLowerCase();
                        final q = searchQuery.toLowerCase();
                        return name.contains(q) || uname.contains(q);
                      }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      searchQuery.isEmpty
                          ? 'No users found'
                          : 'No match for "$searchQuery"',
                      style: AppTheme.body(color: AppTheme.textMuted),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _buildUserCard(filtered[index], followingInProgress),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
              error: (error, stackTrace) =>
                  _buildErrorState(() => ref.invalidate(allUsersProvider)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(
    Map<String, dynamic> user,
    Set<int> followingInProgress,
  ) {
    final followStatus = user['followStatus'];
    final isFollowing =
        (user['isFollowing'] ?? false) || followStatus == 'accepted';
    final isPending = followStatus == 'pending';
    final userId = user['id'] as int;
    final isLoading = followingInProgress.contains(userId);
    final displayName = user['fullName'] ?? user['username'] ?? 'User';
    final username = user['username'] ?? 'user';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.surfaceLight,
            backgroundImage: user['avatarUrl'] != null
                ? NetworkImage(user['avatarUrl'])
                : null,
            child: user['avatarUrl'] == null
                ? Text(
                    initial,
                    style: GoogleFonts.firaCode(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: GoogleFonts.firaCode(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '@$username',
                  style: AppTheme.body(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),

          if (isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primary,
              ),
            )
          else if (isFollowing)
            _statusChip(
              'FOLLOWING',
              AppTheme.secondary,
              () => _unfollowUser(userId),
            )
          else if (isPending)
            _statusChip('PENDING', AppTheme.textMuted, null)
          else
            GestureDetector(
              onTap: () => _followUser(userId),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'FOLLOW',
                  style: GoogleFonts.firaCode(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.background,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: GoogleFonts.firaCode(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 40, color: AppTheme.error),
          const SizedBox(height: 12),
          Text(
            'CONNECTION_ERROR',
            style: GoogleFonts.firaCode(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'RETRY',
              style: GoogleFonts.firaCode(
                fontSize: 13,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
