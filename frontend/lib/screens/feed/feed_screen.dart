import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../core/services/api_service.dart';

// Provider for fetching feed
final feedProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ApiService();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('accessToken');
  
  if (token == null) return [];
  
  try {
    final response = await api.client.get(
      '/feed',
      queryParameters: {'limit': 30},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    
    if (response.data['success'] == true) {
      return response.data['data'] ?? [];
    }
    return [];
  } catch (e) {
    debugPrint('Error fetching feed: $e');
    return [];
  }
});

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.dynamic_feed_rounded, color: AppTheme.accent, size: 22),
            const SizedBox(width: 10),
            Text('Activity Feed', style: GoogleFonts.firaCode(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
          ],
        ),
        centerTitle: true,
      ),
      body: Container(
        child: feedAsync.when(
          data: (activities) {
            if (activities.isEmpty) {
              return _buildEmptyState();
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(feedProvider),
              color: AppTheme.accent,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: activities.length,
                itemBuilder: (context, index) {
                  return _buildActivityItem(activities[index]);
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
          error: (e, s) => Center(
            child: Text('Error loading feed', style: GoogleFonts.firaCode(color: AppTheme.textSecondary)),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.people_outline_rounded, size: 56, color: AppTheme.textMuted.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 24),
            Text(
              'No Activity Yet',
              style: GoogleFonts.firaCode(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Follow more users to see their activities here!',
              textAlign: TextAlign.center,
              style: GoogleFonts.firaCode(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final type = activity['type'] ?? 'unknown';
    final user = activity['user'] ?? {};
    final data = activity['data'] ?? {};
    final userName = user['fullName'] ?? user['username'] ?? 'User';
    final createdAt = activity['createdAt'];

    IconData icon;
    Color iconColor;
    String title;
    String subtitle;

    switch (type) {
      case 'duel_won':
        icon = Icons.emoji_events_rounded;
        iconColor = AppTheme.tertiary;
        title = '$userName won a duel!';
        subtitle = 'Score: ${data['score'] ?? 0} points';
        break;
      case 'duel_completed':
        icon = Icons.flash_on_rounded;
        iconColor = AppTheme.primary;
        title = '$userName completed a duel';
        subtitle = data['topicName'] ?? 'General Knowledge';
        break;
      case 'question_created':
        icon = Icons.add_circle_rounded;
        iconColor = AppTheme.accent;
        title = '$userName created a question';
        subtitle = data['topic'] ?? 'New question added';
        break;
      case 'level_up':
        icon = Icons.arrow_upward_rounded;
        iconColor = AppTheme.secondary;
        title = '$userName leveled up!';
        subtitle = 'Now level ${data['level'] ?? 'unknown'}';
        break;
      case 'achievement':
        icon = Icons.star_rounded;
        iconColor = AppTheme.tertiary;
        title = '$userName earned an achievement';
        subtitle = data['achievement'] ?? 'New milestone reached';
        break;
      default:
        icon = Icons.notifications_rounded;
        iconColor = AppTheme.textMuted;
        title = '$userName did something';
        subtitle = 'Activity';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.firaCode(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.firaCode(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          if (createdAt != null)
            Text(
              _formatTime(createdAt),
              style: GoogleFonts.firaCode(fontSize: 11, color: AppTheme.textMuted),
            ),
        ],
      ),
    );
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${(diff.inDays / 7).floor()}w ago';
    } catch (e) {
      return '';
    }
  }
}
