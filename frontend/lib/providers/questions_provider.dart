import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/questions_service.dart';

final questionsServiceProvider = Provider<QuestionsService>((ref) {
  return QuestionsService();
});

final createQuestionControllerProvider = StateNotifierProvider<CreateQuestionController, AsyncValue<void>>((ref) {
  return CreateQuestionController(ref.watch(questionsServiceProvider));
});

class CreateQuestionController extends StateNotifier<AsyncValue<void>> {
  final QuestionsService _questionsService;

  CreateQuestionController(this._questionsService) : super(const AsyncValue.data(null));

  /// Map difficulty ID to difficulty string
  String _mapDifficultyIdToString(int difficultyId) {
    switch (difficultyId) {
      case 1:
        return 'easy';
      case 2:
        return 'medium';
      case 3:
        return 'hard';
      default:
        return 'medium';
    }
  }

  Future<bool> createQuestion({
    required String questionText,
    required String optionA,
    required String optionB,
    required String optionC,
    required String optionD,
    required String correctOption,
    required int categoryId,
    required int difficultyId,
  }) async {
    state = const AsyncValue.loading();
    try {
      // Transform frontend data format to backend expected format:
      // Backend expects: content, options[], correctAnswer, difficulty, topicIds[]
      final backendData = {
        'content': questionText,
        'options': [
          {'id': 'A', 'text': optionA},
          {'id': 'B', 'text': optionB},
          {'id': 'C', 'text': optionC},
          {'id': 'D', 'text': optionD},
        ],
        'correctAnswer': correctOption, // "A", "B", "C", or "D"
        'difficulty': _mapDifficultyIdToString(difficultyId), // "easy", "medium", "hard"
        'topicIds': [categoryId], // Backend expects array of topic IDs
      };

      await _questionsService.createQuestion(backendData);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}
