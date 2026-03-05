import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/socket_service.dart';

class SpectatorScreen extends ConsumerStatefulWidget {
  final int duelId;
  final String? roomId;

  const SpectatorScreen({super.key, required this.duelId, this.roomId});

  @override
  ConsumerState<SpectatorScreen> createState() => _SpectatorScreenState();
}

class _SpectatorScreenState extends ConsumerState<SpectatorScreen> {
  Map<String, dynamic>? _duelState;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _joinSpectator();
  }

  void _joinSpectator() {
    final socketService = ref.read(socketServiceProvider);

    // Listen for initial state
    socketService.on('spectator:joined', (data) {
      if (mounted) {
        setState(() {
          _duelState = data;
          _isLoading = false;
        });
      }
    });

    // Listen for updates
    socketService.on('spectator:update', (data) {
      if (mounted && _duelState != null) {
        setState(() {
          // Update scores
          if (data['scores'] != null) {
            _duelState!['scores'] = data['scores'];
          }
          // Update progress
          if (data['playerProgress'] != null) {
            _duelState!['playerProgress'] = data['playerProgress'];
          }
        });
      }
    });

    socketService.on('spectator:error', (data) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${data['message']}')));
        Navigator.pop(context);
      }
    });

    // Join
    socketService.joinSpectator(widget.duelId, roomId: widget.roomId);
  }

  @override
  void dispose() {
    final socketService = ref.read(socketServiceProvider);
    if (widget.roomId != null) {
      socketService.leaveSpectator(widget.roomId!);
    }
    socketService.off('spectator:joined');
    socketService.off('spectator:update');
    socketService.off('spectator:error');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_duelState == null) {
      return const Scaffold(body: Center(child: Text('Failed to load duel')));
    }

    final players = _duelState!['players'] as Map<String, dynamic>;
    final scores = _duelState!['scores'] as Map<String, dynamic>;
    final progress = _duelState!['playerProgress'] as Map<String, dynamic>;
    final questions = _duelState!['questions'] as List<dynamic>;

    return Scaffold(
      appBar: AppBar(title: const Text('Spectating Duel')),
      body: Column(
        children: [
          // Scoreboard
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: players.entries.map((entry) {
                final userId = entry.key;
                final score = scores[userId] ?? 0;
                final currentQ = progress[userId] ?? 0;

                return Column(
                  children: [
                    Text(
                      'Player $userId',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Score: $score', style: const TextStyle(fontSize: 24)),
                    Text('Q: ${currentQ + 1} / ${questions.length}'),
                  ],
                );
              }).toList(),
            ),
          ),
          const Divider(),
          // Question View (Show what the leading player is seeing, or just list questions)
          Expanded(
            child: ListView.builder(
              itemCount: questions.length,
              itemBuilder: (context, index) {
                final question = questions[index];
                return ListTile(
                  title: Text(
                    'Q${index + 1}: ${question['text'] ?? 'Question Text'}',
                  ),
                  subtitle: Text(
                    'Difficulty: ${question['difficulty'] ?? 'Medium'}',
                  ),
                  // Highlight if any player is on this question
                  tileColor: _isPlayerOnQuestion(progress, index)
                      ? Colors.blue.withValues(alpha: 0.1)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _isPlayerOnQuestion(Map<String, dynamic> progress, int index) {
    return progress.values.any((p) => p == index);
  }
}
