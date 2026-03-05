import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../core/services/duel_service.dart';
import '../core/services/socket_service.dart';

final categoriesProvider = FutureProvider<List<dynamic>>((ref) async {
  final duelService = ref.watch(duelServiceProvider);
  return duelService.getCategories();
});

final roomCodeProvider = StateProvider<String?>((ref) => null);

final duelStateProvider =
    StateNotifierProvider<DuelNotifier, AsyncValue<Map<String, dynamic>?>>((
      ref,
    ) {
      final socketService = ref.watch(socketServiceProvider);
      return DuelNotifier(socketService, ref);
    });

class DuelNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  final SocketService _socketService;
  final Ref _ref;

  DuelNotifier(this._socketService, this._ref) : super(AsyncValue.data(null)) {
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    // ==================== DUEL EVENTS (Standardized) ====================

    // Game Start (Both Async and Instant)
    _socketService.onDuel('startDuel', (data) {
      debugPrint('⚔️ Duel started (startDuel): $data');
      _handleDuelStarted(data);
    });

    // Game Start (Room Code Flow)
    _socketService.onDuel('duel:started', (data) {
      debugPrint('⚔️ Duel started (duel:started): $data');
      _handleDuelStarted(data);
    });

    // Answer Result (Immediate feedback for THIS player)
    _socketService.onDuel('duel:answer_result', (data) {
      debugPrint('✅ Answer result: $data');

      final resultData = {
        'isCorrect': data['isCorrect'],
        'correctAnswer': data['correctAnswer'],
        'currentScore': data['currentScore'],
        'isSkipped': data['isSkipped'] ?? false,
      };

      _handleAnswerResult(resultData);

      // Update state with result
      state = AsyncValue.data({
        ...?state.value,
        'questionResult': resultData,
        'currentScore': data['currentScore'],
        'lastAnswerResult': resultData,
      });
    });

    // Next Question (For THIS player)
    _socketService.onDuel('duel:next_question', (data) {
      debugPrint('⏭️ Next Question: $data');
      _handleNextQuestion(data);
    });

    // Opponent Progress (Real-time updates)
    _socketService.onDuel('duel:opponent_answered', (data) {
      debugPrint('🆚 Opponent answered: $data');
      _handleOpponentAnswered(data);
    });

    // Player Finished
    _socketService.onDuel('duel:player_finished', (data) {
      debugPrint('🏁 Player finished: $data');
      _handlePlayerFinished(data);
    });

    // Duel Ended (Both finished)
    _socketService.onDuel('duel:completed', (data) {
      debugPrint('🏆 Duel completed: $data');
      _handleDuelEnded(data);
    });

    // Left Early
    _socketService.onDuel('duel:left_early', (data) {
      debugPrint('👋 Left early: $data');
      _handleLeftEarly(data);
    });

    // Opponent Left Early
    _socketService.onDuel('duel:opponent_left_early', (data) {
      debugPrint('🏃 Opponent left early: $data');
      // Just show a toast or update state if needed
    });

    // Room Created
    _socketService.onDuel('duel:room_created', (data) {
      debugPrint('🏠 Room created: $data');
      _handleRoomCreated(data);
    });

    // Error Handling
    _socketService.onDuel('duel:error', (data) {
      debugPrint('❌ Duel error: $data');
      state = AsyncValue.error(
        data['message'] ?? 'An error occurred',
        StackTrace.current,
      );
    });
  }

  @override
  void dispose() {
    _socketService.offDuel('startDuel');
    _socketService.offDuel('duel:started');
    _socketService.offDuel('duel:answer_result');
    _socketService.offDuel('duel:next_question');
    _socketService.offDuel('duel:opponent_answered');
    _socketService.offDuel('duel:player_finished');
    _socketService.offDuel('duel:completed');
    _socketService.offDuel('duel:room_created');
    super.dispose();
  }

  // ==================== HANDLERS ====================

  void _handleRoomCreated(dynamic data) {
    _ref.read(roomCodeProvider.notifier).state = data['roomId'];
  }

  void _handleDuelStarted(dynamic data) {
    // Map backend data to frontend state
    final questions = data['questions'] ?? [];
    final firstQuestion = data['firstQuestion'];

    state = AsyncValue.data({
      'status': 'active',
      'duelId': data['duelId'],
      'roomId': data['roomId'],
      'questions': questions,
      'totalQuestions': questions.length,
      'currentQuestionIndex': 0,
      'currentQuestion':
          firstQuestion?['question'] ??
          (questions.isNotEmpty ? questions[0] : null),
      'currentScore': 0,
      'opponentScore': 0,
      'opponentProgress': 0,
      'timeLimit': firstQuestion?['timeLimit'] ?? 30,
      'startTime': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void _handleAnswerResult(dynamic data) {
    final currentData = state.value;
    if (currentData != null) {
      state = AsyncValue.data({
        ...currentData,
        'questionResult': data,
        'currentScore': data['currentScore'],
      });
    }
  }

  void _handleNextQuestion(dynamic data) {
    final currentData = state.value;
    if (currentData != null) {
      state = AsyncValue.data({
        ...currentData,
        'currentQuestionIndex': data['questionIndex'],
        'currentQuestion': data['question'],
        'timeLimit': data['timeLimit'] ?? 30,
        'questionResult': null, // Clear previous result
      });
    }
  }

  void _handleOpponentAnswered(dynamic data) {
    final currentData = state.value;
    if (currentData != null) {
      state = AsyncValue.data({
        ...currentData,
        'opponentProgress': data['opponentProgress'],
        'opponentScore': data['opponentScore'] ?? currentData['opponentScore'],
      });
    }
  }

  void _handlePlayerFinished(dynamic data) {
    final currentData = state.value;
    if (currentData != null) {
      state = AsyncValue.data({
        ...currentData,
        'status': 'waiting_for_opponent',
        'finalScore': data['yourScore'],
        'myStats': data['stats'], // Store stats
      });
    }
  }

  void _handleDuelEnded(dynamic data) {
    final currentData = state.value;
    if (currentData != null) {
      state = AsyncValue.data({
        ...currentData,
        'status': 'completed',
        'winnerId': data['winnerId'],
        'finalScores': data['scores'],
        'finalResults': data, // Store full results
      });
    }
  }

  void _handleLeftEarly(dynamic data) {
    final currentData = state.value;
    if (currentData != null) {
      state = AsyncValue.data({...currentData, 'status': 'left_early'});
    }
  }
  // ==================== ACTIONS ====================

  void loadDuel(int duelId) {
    debugPrint('🔄 Loading Duel: $duelId');
    state = const AsyncValue.loading();
    _socketService.emitDuel('duel:load', {'duelId': duelId});
  }

  Future<void> sendChallenge(int opponentId, int categoryId) async {
    debugPrint('📨 Sending Challenge to $opponentId for category $categoryId');
    _socketService.emitDuel('invite', {
      'opponentId': opponentId,
      'categoryId': categoryId,
    });
  }

  void joinQueue(int categoryId) {
    debugPrint('🔍 Joining Queue for category $categoryId');
    // Set state to searching so UI can show "Searching for opponent..."
    state = const AsyncValue.data({'status': 'searching'});
    _socketService.emitDuel('duel:join_queue', {'categoryId': categoryId});
  }

  void createRoom(int categoryId, {int questionCount = 5}) {
    debugPrint('🏠 Creating Room: Cat=$categoryId, Count=$questionCount');
    _socketService.emitDuel('duel:create_room', {
      'categoryId': categoryId,
      'questionCount': questionCount,
      'difficultyId': 1, // Default to medium
    });
  }

  void joinRoom(String roomId) {
    debugPrint('👋 Joining Room: $roomId');
    _socketService.emitDuel('duel:join_room', {'roomId': roomId});
  }

  void reset() {
    state = const AsyncValue.data(null);
    _ref.read(roomCodeProvider.notifier).state = null;
  }

  void leaveEarly() {
    debugPrint('👋 Leaving Duel Early');
    _socketService.emitDuel('duel:leave_early', {});
  }

  Future<void> submitAnswer(
    int duelId,
    int questionId,
    String? answer, {
    required int timeUsed,
  }) async {
    final currentData = state.value;
    if (currentData == null) return;

    final roomId = currentData['roomId'];

    // Emit to Duel Namespace
    _socketService.emitDuel('duel:submit_answer', {
      'roomId': roomId,
      'questionId': questionId,
      'answer': answer,
      'timeUsed': timeUsed,
    });
  }
}
