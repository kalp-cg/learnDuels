import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../core/services/api_service.dart';
import '../../screens/profile/profile_screen.dart';

// Provider for admin dashboard stats
final adminStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  final api = ApiService();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('accessToken');

  if (token == null) return {};

  try {
    final response = await api.client.get(
      '/admin/dashboard',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    if (response.data['success'] == true) {
      return response.data['data'] ?? {};
    }
    return {};
  } catch (e) {
    debugPrint('Error fetching admin stats: $e');
    return {};
  }
});

// Provider for moderation queue
final moderationQueueProvider = FutureProvider.autoDispose<List<dynamic>>((
  ref,
) async {
  final api = ApiService();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('accessToken');

  if (token == null) return [];

  try {
    final response = await api.client.get(
      '/admin/moderation/queue',
      queryParameters: {'status': 'pending', 'limit': 50},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    if (response.data['success'] == true) {
      return response.data['data'] ?? [];
    }
    return [];
  } catch (e) {
    debugPrint('Error fetching moderation queue: $e');
    return [];
  }
});

// Provider for all users
final allUsersProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ApiService();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('accessToken');

  if (token == null) return [];

  try {
    final response = await api.client.get(
      '/admin/users',
      queryParameters: {'limit': 50},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    if (response.data['success'] == true) {
      return response.data['users'] ?? [];
    }
    return [];
  } catch (e) {
    debugPrint('Error fetching all users: $e');
    return [];
  }
});

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _approveQuestion(int questionId) async {
    final api = ApiService();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    try {
      await api.client.post(
        '/admin/questions/$questionId/approve',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      ref.invalidate(moderationQueueProvider);
      ref.invalidate(adminStatsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Question approved!', style: GoogleFonts.firaCode()),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to approve: $e',
              style: GoogleFonts.firaCode(),
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _rejectQuestion(int questionId) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        String inputReason = '';
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Reject Reason',
            style: GoogleFonts.firaCode(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            onChanged: (v) => inputReason = v,
            style: GoogleFonts.firaCode(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Enter rejection reason...',
              hintStyle: GoogleFonts.firaCode(color: AppTheme.textMuted),
              filled: true,
              fillColor: AppTheme.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.firaCode(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, inputReason),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              child: Text('Reject', style: GoogleFonts.firaCode()),
            ),
          ],
        );
      },
    );

    if (reason == null || reason.isEmpty) return;

    final api = ApiService();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    try {
      await api.client.post(
        '/admin/questions/$questionId/reject',
        data: {'reason': reason},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      ref.invalidate(moderationQueueProvider);
      ref.invalidate(adminStatsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Question rejected', style: GoogleFonts.firaCode()),
            backgroundColor: AppTheme.surfaceLight,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error rejecting: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppTheme.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: AppTheme.secondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Admin Panel',
              style: GoogleFonts.firaCode(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.secondary,
          indicatorWeight: 3,
          labelColor: AppTheme.secondary,
          unselectedLabelColor: AppTheme.textMuted,
          labelStyle: GoogleFonts.firaCode(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Users'),
            Tab(text: 'Moderation'),
          ],
        ),
      ),
      body: Container(
        color: AppTheme.background,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildDashboard(),
            _buildUsersList(),
            _buildModerationQueue(),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final statsAsync = ref.watch(adminStatsProvider);

    return statsAsync.when(
      data: (stats) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Overview',
                style: GoogleFonts.firaCode(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Stats grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: [
                  _buildStatCard(
                    'Total Users',
                    stats['totalUsers']?.toString() ?? '0',
                    Icons.people_rounded,
                    AppTheme.primary,
                  ),
                  _buildStatCard(
                    'Questions',
                    stats['totalQuestions']?.toString() ?? '0',
                    Icons.quiz_rounded,
                    AppTheme.accent,
                  ),
                  _buildStatCard(
                    'Pending',
                    stats['pendingQuestions']?.toString() ?? '0',
                    Icons.pending_rounded,
                    AppTheme.tertiary,
                  ),
                  _buildStatCard(
                    'Duels Today',
                    stats['duelsToday']?.toString() ?? '0',
                    Icons.flash_on_rounded,
                    AppTheme.secondary,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Quick actions
              Text(
                'Quick Actions',
                style: GoogleFonts.firaCode(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              _buildActionButton(
                'View Moderation Queue',
                Icons.inbox_rounded,
                () => _tabController.animateTo(1),
              ),
              const SizedBox(height: 12),
              _buildActionButton(
                'View Flagged Content',
                Icons.flag_rounded,
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Coming soon!',
                        style: GoogleFonts.firaCode(),
                      ),
                      backgroundColor: AppTheme.surfaceLight,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.secondary),
      ),
      error: (e, s) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppTheme.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load admin data',
              style: GoogleFonts.firaCode(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Make sure you have admin permissions',
              style: GoogleFonts.firaCode(
                color: AppTheme.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.firaCode(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.firaCode(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.textSecondary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.firaCode(
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildModerationQueue() {
    final queueAsync = ref.watch(moderationQueueProvider);

    return queueAsync.when(
      data: (questions) {
        if (questions.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      size: 48,
                      color: AppTheme.success,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'All Caught Up!',
                    style: GoogleFonts.firaCode(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No pending questions to review',
                    style: GoogleFonts.firaCode(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(moderationQueueProvider);
          },
          color: AppTheme.secondary,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final question = questions[index];
              return _buildQuestionCard(question);
            },
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.secondary),
      ),
      error: (e, s) => Center(
        child: Text(
          'Error loading queue',
          style: GoogleFonts.firaCode(color: AppTheme.textSecondary),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> question) {
    final content = question['content'] ?? 'No content';
    final difficulty = question['difficulty'] ?? 'medium';
    final author = question['author'] ?? {};
    final authorName = author['fullName'] ?? author['username'] ?? 'Unknown';
    final options = question['options'] as List<dynamic>? ?? [];

    Color diffColor;
    if (difficulty == 'easy') {
      diffColor = AppTheme.success;
    } else if (difficulty == 'medium') {
      diffColor = AppTheme.tertiary;
    } else {
      diffColor = AppTheme.secondary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: diffColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  difficulty.toString().toUpperCase(),
                  style: GoogleFonts.firaCode(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: diffColor,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'By $authorName',
                style: GoogleFonts.firaCode(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Question content
          Text(
            content,
            style: GoogleFonts.firaCode(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              height: 1.4,
            ),
          ),

          if (options.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...options.take(4).map((opt) {
              final isCorrect = opt['id'] == question['correctAnswer'];
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isCorrect
                      ? AppTheme.success.withValues(alpha: 0.1)
                      : AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCorrect
                        ? AppTheme.success.withValues(alpha: 0.3)
                        : AppTheme.border.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '${opt['id']}. ',
                      style: GoogleFonts.firaCode(
                        color: isCorrect
                            ? AppTheme.success
                            : AppTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        opt['text'] ?? '',
                        style: GoogleFonts.firaCode(
                          color: isCorrect
                              ? AppTheme.success
                              : AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (isCorrect)
                      const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: AppTheme.success,
                      ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _rejectQuestion(question['id']),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: Text('Reject', style: GoogleFonts.firaCode()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: BorderSide(
                      color: AppTheme.error.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.success, Color(0xFF00C78A)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _approveQuestion(question['id']),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Approve',
                              style: GoogleFonts.firaCode(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
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
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    final usersAsync = ref.watch(allUsersProvider);

    return usersAsync.when(
      data: (users) {
        if (users.isEmpty) {
          return Center(
            child: Text(
              'No users found',
              style: GoogleFonts.firaCode(color: AppTheme.textSecondary),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(allUsersProvider),
          color: AppTheme.secondary,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return _buildUserListItem(user);
            },
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.secondary),
      ),
      error: (e, s) => Center(
        child: Text(
          'Error loading users',
          style: GoogleFonts.firaCode(color: AppTheme.textSecondary),
        ),
      ),
    );
  }

  Widget _buildUserListItem(Map<String, dynamic> user) {
    final username = user['username'] ?? 'Unknown';
    final email = user['email'] ?? '';
    final role = user['role'] ?? 'user';
    final isActive = user['isActive'] ?? true;
    final avatarUrl = user['avatarUrl'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary,
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? Text(
                  username[0].toUpperCase(),
                  style: GoogleFonts.firaCode(color: Colors.white),
                )
              : null,
        ),
        title: Text(
          username,
          style: GoogleFonts.firaCode(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              email,
              style: GoogleFonts.firaCode(
                color: AppTheme.textMuted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: role == 'admin'
                        ? AppTheme.secondary.withValues(alpha: 0.2)
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: role == 'admin'
                          ? AppTheme.secondary
                          : AppTheme.border.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: GoogleFonts.firaCode(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: role == 'admin'
                          ? AppTheme.secondary
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (!isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'SUSPENDED',
                      style: GoogleFonts.firaCode(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppTheme.textMuted,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfileScreen()),
          );
        },
      ),
    );
  }
}
