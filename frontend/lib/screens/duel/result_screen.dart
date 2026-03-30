import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/duel_provider.dart';
import '../../core/services/user_service.dart';

class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    var userId = prefs.getString('userId');

    if (userId == null) {
      debugPrint('⚠️ User ID not found in prefs, fetching profile...');
      try {
        final userProfile = await ref.read(userServiceProvider).getProfile();
        if (userProfile != null && userProfile['id'] != null) {
          userId = userProfile['id'].toString();
          await prefs.setString('userId', userId);
          debugPrint('✅ User ID fetched and saved: $userId');
        } else {
          debugPrint('❌ User profile is null or missing ID');
        }
      } catch (e) {
        debugPrint('❌ Failed to fetch user profile: $e');
      }
    } else {
      debugPrint('✅ User ID found in prefs: $userId');
    }

    if (mounted) {
      setState(() {
        _currentUserId = userId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final duelState = ref.watch(duelStateProvider);

    // We can use args for initial display, but prefer duelState for real-time updates
    Map<String, dynamic> resultData = {};
    final stateValue = duelState.value;

    // Check for waiting status first
    final status = stateValue?['status'] ?? args?['status'];

    if (status == 'waiting_for_opponent') {
      return _buildWaitingScreen(context, stateValue ?? args ?? {});
    }

    if (stateValue != null &&
        stateValue['status'] == 'completed' &&
        stateValue['finalResults'] != null) {
      // Ensure it's treated as a Map
      if (stateValue['finalResults'] is Map) {
        resultData = Map<String, dynamic>.from(stateValue['finalResults']);
      }
    } else if (args != null) {
      resultData = args;
    }

    if (resultData.isEmpty) {
      return const Scaffold(body: Center(child: Text('No result data')));
    }

    // Wait for user ID to load to avoid false "Defeat" state
    if (_currentUserId == null) {
      // If we have result data but no user ID, try to infer it from players list if possible
      // Or just show loading.
      // If it takes too long, we might want to show an error or retry button.
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Loading user profile...'),
              const SizedBox(height: 16),
              TextButton(onPressed: _loadUser, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final winnerId = resultData['winnerId']?.toString();

    debugPrint(
      '🏆 ResultScreen: winnerId=$winnerId, currentUserId=$_currentUserId',
    );

    // Determine win/loss/tie
    final isWin = winnerId != null && winnerId == _currentUserId;
    final isTie = winnerId == null;

    // No rematch feature - just show results

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color:
                      (isTie
                              ? Colors.orange
                              : (isWin ? Colors.green : Colors.red))
                          .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isTie
                      ? Icons.balance_rounded
                      : (isWin
                            ? Icons.emoji_events_rounded
                            : Icons.close_rounded),
                  size: 80,
                  color: isTie
                      ? Colors.orange
                      : (isWin ? Colors.green : Colors.red),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isTie ? 'It\'s a Tie!' : (isWin ? 'Victory!' : 'Defeat!'),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isTie
                      ? Colors.orange
                      : (isWin ? Colors.green : Colors.red),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Player stats comparison
              _buildPlayerStatsCard(resultData, _currentUserId),

              const SizedBox(height: 32),

              // Back to Home Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(duelStateProvider.notifier).reset();
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/home',
                      (route) => false,
                    );
                  },
                  child: Text(
                    'Back to Home',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingScreen(BuildContext context, Map<String, dynamic> data) {
    final score = data['finalScore'] ?? data['currentScore'] ?? 0;
    final stats = data['myStats'];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  size: 80,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'You Finished!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Your Score: $score',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              if (stats != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            context,
                            Icons.check_circle,
                            Colors.green,
                            '${stats['correctAnswers'] ?? 0}',
                            'Correct',
                          ),
                          _buildStatItem(
                            context,
                            Icons.cancel,
                            Colors.red,
                            '${stats['wrongAnswers'] ?? 0}',
                            'Wrong',
                          ),
                          _buildStatItem(
                            context,
                            Icons.skip_next,
                            Colors.grey,
                            '${stats['skippedAnswers'] ?? 0}',
                            'Skipped',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: Theme.of(context).hintColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Total Time: ${stats['timeTaken'] ?? 0}s',
                            style: TextStyle(
                              color: Theme.of(context).hintColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),
              const Text(
                'Waiting for opponent to finish...',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'You can stay here to see the results live, or leave now and get notified later.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 48),
              SizedBox(
                height: 56,
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(duelStateProvider.notifier).reset();
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/home',
                      (route) => false,
                    );
                  },
                  child: const Text('Leave Duel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    Color color,
    String value,
    String label,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildPlayerStatsCard(
    Map<String, dynamic> resultData,
    String? currentUserId,
  ) {
    // Robust parsing of players map
    Map<String, dynamic> players = {};
    try {
      final rawPlayers = resultData['players'];
      if (rawPlayers is Map) {
        players = Map<String, dynamic>.from(rawPlayers);
      }
    } catch (e) {
      debugPrint('Error parsing players map: $e');
    }

    final winnerId = resultData['winnerId']?.toString();
    final totalQuestions = resultData['totalQuestions'] ?? 0;

    if (players.isEmpty) {
      // Fallback to old format or show waiting message
      final scores = resultData['scores'] as Map<String, dynamic>? ?? {};
      final userScore = scores[currentUserId] ?? 0;

      return Column(
        children: [
          Text(
            'Your Score: $userScore',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Waiting for detailed results...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      );
    }

    final playerList = players.entries.toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Final Score',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (totalQuestions > 0)
            Text(
              '$totalQuestions Questions',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
          const SizedBox(height: 8),
          // Total Time Display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 16,
                color: Theme.of(context).hintColor,
              ),
              const SizedBox(width: 4),
              Text(
                'Total Time',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: playerList.map((entry) {
              final playerId = entry.key.toString(); // Ensure string
              final playerData = Map<String, dynamic>.from(entry.value as Map);
              final isWinner = winnerId?.toString() == playerId;
              final isCurrentUser = playerId == currentUserId?.toString();

              return Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isWinner
                        ? Colors.green.withValues(alpha: 0.1)
                        : Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: isCurrentUser
                        ? Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          )
                        : null,
                  ),
                  child: Column(
                    children: [
                      if (isWinner)
                        const Icon(
                          Icons.emoji_events,
                          color: Colors.amber,
                          size: 20,
                        ),
                      Text(
                        isCurrentUser
                            ? 'You'
                            : (playerData['name'] ?? 'Opponent'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isWinner ? Colors.green : null,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${playerData['score'] ?? 0}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isWinner
                              ? Colors.green
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Text(
                        'points',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      // Correct/Wrong/Skipped counts
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${playerData['correctAnswers'] ?? 0}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.green),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.cancel, size: 14, color: Colors.red),
                          const SizedBox(width: 2),
                          Text(
                            '${playerData['wrongAnswers'] ?? 0}',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: Colors.red),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.skip_next, size: 14, color: Colors.grey),
                          const SizedBox(width: 2),
                          Text(
                            '${playerData['skippedAnswers'] ?? 0}',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 14,
                            color: Theme.of(context).hintColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${playerData['timeTaken'] ?? 0}s',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Theme.of(context).hintColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
