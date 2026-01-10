import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../core/services/api_service.dart';

// Provider for fetching challenges
final pendingChallengesProvider =
    FutureProvider.autoDispose<Map<String, List<dynamic>>>((ref) async {
      final api = ApiService();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      if (token == null) return {'received': [], 'sent': []};

      try {
        final response = await api.client.get(
          '/challenges',
          queryParameters: {'status': 'PENDING', 'limit': 50},
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );

        if (response.data['success'] == true) {
          final challenges = response.data['data'] as List? ?? [];

          // Get current user ID
          final meResponse = await api.client.get(
            '/auth/me',
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          );
          final userId = meResponse.data['data']?['id'];

          // Separate received and sent
          final received = challenges
              .where(
                (c) =>
                    c['opponentId'] == userId ||
                    (c['participants'] != null &&
                        (c['participants'] as List).any(
                          (p) =>
                              p['userId'] == userId && p['status'] == 'invited',
                        )),
              )
              .toList();
          final sent = challenges
              .where((c) => c['challengerId'] == userId)
              .toList();

          return {'received': received, 'sent': sent};
        }
        return {'received': [], 'sent': []};
      } catch (e) {
        debugPrint('Error fetching challenges: $e');
        return {'received': [], 'sent': []};
      }
    });

class PendingChallengesScreen extends ConsumerStatefulWidget {
  const PendingChallengesScreen({super.key});

  @override
  ConsumerState<PendingChallengesScreen> createState() =>
      _PendingChallengesScreenState();
}

class _PendingChallengesScreenState
    extends ConsumerState<PendingChallengesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _acceptChallenge(int challengeId) async {
    final api = ApiService();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    try {
      final response = await api.client.post(
        '/challenges/$challengeId/accept',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      ref.invalidate(pendingChallengesProvider);

      if (mounted) {
        final data = response.data['data'];
        final duelId = data['duelId']; // Note: ensure backend returns duelId

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Challenge accepted! Starting quiz...',
              style: GoogleFonts.outfit(),
            ),
            backgroundColor: AppTheme.success,
          ),
        );

        if (duelId != null) {
          Navigator.pushNamed(context, '/duel', arguments: {'duelId': duelId});
        } else {
          debugPrint('Warning: No duelId returned from accept challenge');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept: $e', style: GoogleFonts.outfit()),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _declineChallenge(int challengeId) async {
    final api = ApiService();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    try {
      await api.client.delete(
        '/challenges/$challengeId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      ref.invalidate(pendingChallengesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Challenge declined', style: GoogleFonts.outfit()),
            backgroundColor: AppTheme.surfaceLight,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error declining challenge: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final challengesAsync = ref.watch(pendingChallengesProvider);

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
        title: Text(
          'Challenges',
          style: GoogleFonts.outfit(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textMuted,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Received'),
            Tab(text: 'Sent'),
          ],
        ),
      ),
      body: Container(
        color: AppTheme.background,
        child: challengesAsync.when(
          data: (data) {
            return TabBarView(
              controller: _tabController,
              children: [
                _buildChallengeList(data['received'] ?? [], isReceived: true),
                _buildChallengeList(data['sent'] ?? [], isReceived: false),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
          error: (e, s) => Center(
            child: Text(
              'Error loading challenges',
              style: GoogleFonts.outfit(color: AppTheme.textSecondary),
            ),
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => Navigator.pushNamed(context, '/send-challenge'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(
            'New Challenge',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeList(
    List<dynamic> challenges, {
    required bool isReceived,
  }) {
    if (challenges.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isReceived ? Icons.inbox_rounded : Icons.send_rounded,
                  size: 48,
                  color: AppTheme.textMuted.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isReceived ? 'No Challenges Received' : 'No Challenges Sent',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isReceived
                    ? 'When friends challenge you, they\'ll appear here'
                    : 'Challenge your friends to a quiz duel!',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(pendingChallengesProvider),
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: challenges.length,
        itemBuilder: (context, index) {
          final challenge = challenges[index];
          return _buildChallengeCard(challenge, isReceived: isReceived);
        },
      ),
    );
  }

  Widget _buildChallengeCard(
    Map<String, dynamic> challenge, {
    required bool isReceived,
  }) {
    final challenger = challenge['challenger'] ?? {};
    final settings = challenge['settings'] ?? {};
    final challengerName =
        challenger['fullName'] ?? challenger['username'] ?? 'Unknown';
    final topicName = settings['topicName'] ?? 'General';
    final difficulty = settings['difficulty'] ?? 'medium';
    final questionCount = settings['questionCount'] ?? 5;

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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isReceived ? AppTheme.accent : AppTheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    challengerName[0].toUpperCase(),
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
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
                      isReceived ? 'Challenge from' : 'Challenge to',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    Text(
                      challengerName,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
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
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: diffColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Details
          Row(
            children: [
              _buildDetailChip(Icons.category_rounded, topicName),
              const SizedBox(width: 12),
              _buildDetailChip(Icons.quiz_rounded, '$questionCount questions'),
            ],
          ),

          if (isReceived) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _declineChallenge(challenge['id']),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppTheme.textMuted.withValues(alpha: 0.3),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Decline',
                      style: GoogleFonts.outfit(color: AppTheme.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _acceptChallenge(challenge['id']),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              'Accept & Play',
                              style: GoogleFonts.outfit(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.pending_rounded, size: 16, color: AppTheme.tertiary),
                const SizedBox(width: 6),
                Text(
                  'Waiting for response...',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppTheme.tertiary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
