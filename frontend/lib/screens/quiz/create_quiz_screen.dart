import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/question_set_service.dart';
import '../../core/services/topic_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'create_question_screen.dart';

class CreateQuizScreen extends ConsumerStatefulWidget {
  const CreateQuizScreen({super.key});

  @override
  ConsumerState<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends ConsumerState<CreateQuizScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  int? _selectedTopicId;
  String _visibility = 'PUBLIC';
  bool _isLoading = false;
  final List<Map<String, dynamic>> _questions = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _addQuestion() async {
    // Navigate to question creation screen
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => const CreateQuestionScreen()),
    );

    if (result != null && mounted) {
      setState(() {
        _questions.add(result);
      });
    }
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
  }

  Future<void> _createQuiz() async {
    if (!_formKey.currentState!.validate()) return;

    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one question')),
      );
      return;
    }

    if (_selectedTopicId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a topic')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = QuestionSetService();
      await service.createQuestionSet(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        topicId: _selectedTopicId!,
        visibility: _visibility,
        questions: _questions,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quiz created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating quiz: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topicsAsync = ref.watch(topicsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Quiz'),
        actions: [
          if (_questions.isNotEmpty)
            TextButton(
              onPressed: _isLoading ? null : _createQuiz,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Publish'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CustomTextField(
              label: 'Quiz Title',
              hint: 'Enter a catchy title',
              controller: _titleController,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'What is this quiz about?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Topic Selector
            topicsAsync.when(
              data: (topics) => DropdownButtonFormField<int>(
                initialValue: _selectedTopicId,
                decoration: InputDecoration(
                  labelText: 'Topic',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                hint: const Text('Select a topic'),
                items: topics.map<DropdownMenuItem<int>>((topic) {
                  return DropdownMenuItem<int>(
                    value: topic['id'],
                    child: Text(topic['name'] ?? ''),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedTopicId = value);
                },
                validator: (value) {
                  if (value == null) return 'Please select a topic';
                  return null;
                },
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) => Text('Error loading topics: $error'),
            ),
            const SizedBox(height: 16),

            // Visibility Selector
            DropdownButtonFormField<String>(
              initialValue: _visibility,
              decoration: InputDecoration(
                labelText: 'Visibility',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'PUBLIC', child: Text('Public')),
                DropdownMenuItem(value: 'PRIVATE', child: Text('Private')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _visibility = value);
              },
            ),
            const SizedBox(height: 24),

            // Questions Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Questions (${_questions.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton.icon(
                  onPressed: _addQuestion,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Question'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_questions.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.quiz_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No questions yet',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _addQuestion,
                        child: const Text('Add your first question'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._questions.asMap().entries.map((entry) {
                final index = entry.key;
                final question = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text(
                      question['content'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'Difficulty: ${question['difficulty'] ?? 'N/A'}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeQuestion(index),
                    ),
                  ),
                );
              }),

            const SizedBox(height: 24),
            if (_questions.isNotEmpty)
              CustomButton(
                text: 'Create Quiz',
                isLoading: _isLoading,
                onPressed: _createQuiz,
              ),
          ],
        ),
      ),
    );
  }
}

// Topics provider
final topicsProvider = FutureProvider<List<dynamic>>((ref) async {
  final service = TopicService();
  return await service.getTopics();
});
