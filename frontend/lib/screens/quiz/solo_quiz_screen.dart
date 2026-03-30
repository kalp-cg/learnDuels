import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/attempt_service.dart';
import '../../providers/user_provider.dart';
import 'quiz_result_screen.dart';

class SoloQuizScreen extends ConsumerStatefulWidget {
  final int attemptId;
  final List<dynamic> questions;
  final int? topicId;
  final String? difficulty;

  const SoloQuizScreen({
    super.key,
    required this.attemptId,
    required this.questions,
    this.topicId,
    this.difficulty,
  });

  @override
  ConsumerState<SoloQuizScreen> createState() => _SoloQuizScreenState();
}

class _SoloQuizScreenState extends ConsumerState<SoloQuizScreen> {
  int _currentQuestionIndex = 0;
  int? _selectedAnswerIndex;
  bool _isSubmitting = false;
  bool _answered = false;
  bool _isCorrect = false;
  final AttemptService _attemptService = AttemptService();

  void _selectAnswer(int index) {
    if (_answered || _isSubmitting) return;
    setState(() {
      _selectedAnswerIndex = index;
    });
  }

  void _clearSelection() {
    if (_answered || _isSubmitting) return;
    setState(() {
      _selectedAnswerIndex = null;
    });
  }

  void _skipQuestion() {
    if (_answered || _isSubmitting) return;
    _nextQuestion();
  }

  void _submitAnswer() async {
    if (_selectedAnswerIndex == null || _answered || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final question = widget.questions[_currentQuestionIndex];
      // Submit answer to backend and get immediate feedback
      final result = await _attemptService.submitAnswer(
        widget.attemptId,
        question['id'],
        _selectedAnswerIndex!,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _answered = true;
          _isCorrect = result['isCorrect'] ?? false;
        });

        // Show result briefly before moving to next question
        await Future.delayed(const Duration(milliseconds: 800));

        if (mounted) {
          _nextQuestion();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error submitting answer: $e')));
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < widget.questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswerIndex = null;
        _answered = false;
        _isCorrect = false;
      });
    } else {
      _finishQuiz();
    }
  }

  void _finishQuiz() async {
    try {
      final attempt = await _attemptService.completeAttempt(widget.attemptId);

      // Invalidate user providers to refresh stats
      ref.invalidate(userProfileProvider);
      ref.invalidate(userStatsProvider);

      if (mounted) {
        // Calculate stats
        final answers = (attempt['answers'] as List<dynamic>?) ?? [];
        final totalQuestions = widget.questions.length;
        final attempted = answers.length;
        final correct = answers.where((a) => a['isCorrect'] == true).length;
        final wrong = attempted - correct;
        final skipped = totalQuestions - attempted;

        // Navigate to results
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => QuizResultScreen(
              totalQuestions: totalQuestions,
              attempted: attempted,
              correct: correct,
              wrong: wrong,
              skipped: skipped,
              topicId: widget.topicId,
              difficulty: widget.difficulty,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error completing quiz: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[_currentQuestionIndex];
    final options = question['options'] as List<dynamic>;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Theme.of(context).iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Question ${_currentQuestionIndex + 1}/${widget.questions.length}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: !_isSubmitting ? _finishQuiz : null,
            child: Text(
              'End Quiz',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentQuestionIndex + 1) / widget.questions.length,
                  backgroundColor: Theme.of(
                    context,
                  ).dividerColor.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 32),

              // Question Text
              Text(
                question['content'] ?? 'Question text missing',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 40),

              // Options
              Expanded(
                child: ListView.separated(
                  itemCount: options.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final String optionText = option is Map
                        ? (option['text'] ?? '')
                        : option.toString();
                    final String optionId = option is Map
                        ? (option['id']?.toString() ?? '')
                        : option.toString();
                    final isSelected = _selectedAnswerIndex == index;
                    final String correctAnswerId =
                        question['correctAnswer']?.toString() ?? '';
                    final bool isCorrectOption = optionId == correctAnswerId;

                    Color borderColor = Theme.of(context).dividerColor;
                    Color backgroundColor =
                        Theme.of(context).cardTheme.color ??
                        Theme.of(context).cardColor;

                    if (_answered) {
                      if (isSelected) {
                        // User's selected answer
                        borderColor = _isCorrect
                            ? Colors.green
                            : Theme.of(context).colorScheme.error;
                        backgroundColor = _isCorrect
                            ? Colors.green.withValues(alpha: 0.1)
                            : Theme.of(
                                context,
                              ).colorScheme.error.withValues(alpha: 0.1);
                      } else if (isCorrectOption && !_isCorrect) {
                        // Show correct answer if user got it wrong
                        borderColor = Colors.green;
                        backgroundColor = Colors.green.withValues(alpha: 0.1);
                      }
                    } else if (isSelected) {
                      borderColor = Theme.of(context).colorScheme.primary;
                      backgroundColor = Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1);
                    }

                    return GestureDetector(
                      onTap: () => _selectAnswer(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: borderColor,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? borderColor
                                    : Theme.of(
                                        context,
                                      ).dividerColor.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                String.fromCharCode(65 + index),
                                style: TextStyle(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color
                                            ?.withValues(alpha: 0.5),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                optionText,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      fontWeight:
                                          isSelected ||
                                              (_answered && isCorrectOption)
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: _answered && isCorrectOption
                                          ? Colors.green
                                          : isSelected
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Theme.of(
                                              context,
                                            ).textTheme.bodyLarge?.color,
                                    ),
                              ),
                            ),
                            if (_answered && isSelected)
                              Icon(
                                _isCorrect ? Icons.check_circle : Icons.cancel,
                                color: _isCorrect
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.error,
                              ),
                            if (_answered && isCorrectOption && !isSelected)
                              Icon(Icons.check_circle, color: Colors.green),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons (Clear & Skip)
              if (!_answered)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: _selectedAnswerIndex != null
                            ? _clearSelection
                            : null,
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Clear Selection'),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                          disabledForegroundColor: Theme.of(
                            context,
                          ).disabledColor,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _skipQuestion,
                        icon: const Icon(Icons.skip_next),
                        label: const Text('Skip Question'),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),

              // Submit / Next Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed:
                      (_selectedAnswerIndex != null ||
                              _currentQuestionIndex ==
                                  widget.questions.length - 1) &&
                          !_isSubmitting
                      ? () {
                          if (_selectedAnswerIndex != null) {
                            _submitAnswer();
                          } else {
                            _finishQuiz();
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    disabledBackgroundColor: Theme.of(context).disabledColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.onPrimary,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _currentQuestionIndex < widget.questions.length - 1
                              ? 'Submit Answer'
                              : 'Finish Quiz',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimary,
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
}
