import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../core/services/api_service.dart';
import '../friends/friends_screen.dart';

// Challenge provider
final sendChallengeProvider =
    StateNotifierProvider<SendChallengeNotifier, SendChallengeState>((ref) {
      return SendChallengeNotifier();
    });

class SendChallengeState {
  final bool isLoading;
  final String? error;
  final bool success;

  SendChallengeState({
    this.isLoading = false,
    this.error,
    this.success = false,
  });
}

class SendChallengeNotifier extends StateNotifier<SendChallengeState> {
  SendChallengeNotifier() : super(SendChallengeState());

  Future<Map<String, dynamic>?> sendChallenge({
    required int opponentId,
    required int topicId,
    required String difficulty,
    required int questionCount,
  }) async {
    state = SendChallengeState(isLoading: true);

    try {
      final api = ApiService();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      final response = await api.client.post(
        '/challenges',
        data: {
          'opponentId': opponentId,
          'type': 'instant',
          'settings': {
            'topicId': topicId,
            'difficulty': difficulty,
            'questionCount': questionCount,
          },
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      state = SendChallengeState(success: true);
      return response.data['data'] as Map<String, dynamic>?;
    } catch (e) {
      state = SendChallengeState(error: e.toString());
      return null;
    }
  }

  void reset() {
    state = SendChallengeState();
  }
}

class SendChallengeScreen extends ConsumerStatefulWidget {
  final int? preselectedOpponentId;
  final String? preselectedOpponentName;

  const SendChallengeScreen({
    super.key,
    this.preselectedOpponentId,
    this.preselectedOpponentName,
  });

  @override
  ConsumerState<SendChallengeScreen> createState() =>
      _SendChallengeScreenState();
}

class _SendChallengeScreenState extends ConsumerState<SendChallengeScreen> {
  int? _selectedOpponentId;
  String? _selectedOpponentName;
  int? _selectedTopicId;
  String? _selectedTopicName;
  String _selectedDifficulty = 'medium';
  int _questionCount = 5;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedOpponentId != null) {
      _selectedOpponentId = widget.preselectedOpponentId;
      _selectedOpponentName = widget.preselectedOpponentName;
    }
  }

  Future<void> _selectOpponent() async {
    final friendsAsync = ref.read(friendsProvider);

    friendsAsync.whenData((friends) {
      showModalBottomSheet(
        context: context,
        backgroundColor: AppTheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Opponent',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              if (friends.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No friends yet. Follow some users first!',
                    style: GoogleFonts.outfit(color: AppTheme.textSecondary),
                  ),
                )
              else
                ...friends.take(10).map((friend) {
                  final name =
                      friend['fullName'] ?? friend['username'] ?? 'User';
                  return ListTile(
                    onTap: () {
                      setState(() {
                        _selectedOpponentId = friend['id'];
                        _selectedOpponentName = name;
                      });
                      Navigator.pop(context);
                    },
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primary,
                      child: Text(
                        name[0].toUpperCase(),
                        style: GoogleFonts.outfit(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      name,
                      style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                    ),
                    subtitle: Text(
                      '@${friend['username']}',
                      style: GoogleFonts.outfit(color: AppTheme.textMuted),
                    ),
                  );
                }),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _selectTopic() async {
    final api = ApiService();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    try {
      final response = await api.client.get(
        '/topics',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.data['success'] == true && mounted) {
        final topics = response.data['data'] as List;

        showModalBottomSheet(
          context: context,
          backgroundColor: AppTheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => Container(
            padding: const EdgeInsets.all(20),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Topic',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: topics.length,
                    itemBuilder: (context, index) {
                      final topic = topics[index];
                      return ListTile(
                        onTap: () {
                          setState(() {
                            _selectedTopicId = topic['id'];
                            _selectedTopicName = topic['name'];
                          });
                          Navigator.pop(context);
                        },
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.category_rounded,
                            color: AppTheme.accent,
                          ),
                        ),
                        title: Text(
                          topic['name'],
                          style: GoogleFonts.outfit(
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error fetching topics: $e');
    }
  }

  Future<void> _sendChallenge() async {
    if (_selectedOpponentId == null || _selectedTopicId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select opponent and topic',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    // Send challenge
    final result = await ref
        .read(sendChallengeProvider.notifier)
        .sendChallenge(
          opponentId: _selectedOpponentId!,
          topicId: _selectedTopicId!,
          difficulty: _selectedDifficulty,
          questionCount: _questionCount,
        );

    if (result != null && mounted) {
      // Navigate to duel screen immediately
      Navigator.pushReplacementNamed(
        context,
        '/duel',
        arguments: {'duelId': result['id']},
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(sendChallengeProvider).error ?? 'Failed to send challenge',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sendChallengeProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppTheme.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Send Challenge',
          style: GoogleFonts.outfit(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.background, Color(0xFF0F1228)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.accent.withValues(alpha: 0.15),
                      AppTheme.primary.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.flash_on_rounded,
                        color: AppTheme.accent,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Async Challenge',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'Challenge a friend - they can respond anytime!',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Select Opponent
              _buildSectionTitle('Opponent'),
              const SizedBox(height: 12),
              _buildSelectionCard(
                icon: Icons.person_rounded,
                title: _selectedOpponentName ?? 'Select opponent',
                subtitle: _selectedOpponentId != null
                    ? 'Tap to change'
                    : 'Choose from your friends',
                isSelected: _selectedOpponentId != null,
                onTap: _selectOpponent,
              ),
              const SizedBox(height: 24),

              // Select Topic
              _buildSectionTitle('Topic'),
              const SizedBox(height: 12),
              _buildSelectionCard(
                icon: Icons.category_rounded,
                title: _selectedTopicName ?? 'Select topic',
                subtitle: _selectedTopicId != null
                    ? 'Tap to change'
                    : 'Choose a quiz topic',
                isSelected: _selectedTopicId != null,
                onTap: _selectTopic,
              ),
              const SizedBox(height: 24),

              // Difficulty
              _buildSectionTitle('Difficulty'),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildDifficultyChip('easy', 'Easy', AppTheme.success),
                  const SizedBox(width: 10),
                  _buildDifficultyChip('medium', 'Medium', AppTheme.tertiary),
                  const SizedBox(width: 10),
                  _buildDifficultyChip('hard', 'Hard', AppTheme.secondary),
                ],
              ),
              const SizedBox(height: 24),

              // Question Count
              _buildSectionTitle('Questions'),
              const SizedBox(height: 12),
              Row(
                children: [5, 10, 15].map((count) {
                  final isSelected = _questionCount == count;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _questionCount = count),
                      child: Container(
                        margin: EdgeInsets.only(right: count != 15 ? 10 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.border.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$count',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 40),

              // Send Button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: state.isLoading ? null : _sendChallenge,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Center(
                        child: state.isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Send Challenge',
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),

              if (state.error != null) ...[
                const SizedBox(height: 16),
                Text(
                  state.error!,
                  style: GoogleFonts.outfit(color: AppTheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildSelectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.5)
                : AppTheme.border.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withValues(alpha: 0.2)
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppTheme.primary : AppTheme.textMuted,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyChip(String value, String label, Color color) {
    final isSelected = _selectedDifficulty == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedDifficulty = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.2)
                : AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? color
                  : AppTheme.border.withValues(alpha: 0.3),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
