import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/saved_service.dart';

final savedQuestionsProvider = FutureProvider.autoDispose<List<dynamic>>((
  ref,
) async {
  final service = ref.read(savedServiceProvider);
  final result = await service.getSavedQuestions();
  return result['data'] ?? [];
});

class SavedQuestionsScreen extends ConsumerStatefulWidget {
  const SavedQuestionsScreen({super.key});

  @override
  ConsumerState<SavedQuestionsScreen> createState() =>
      _SavedQuestionsScreenState();
}

class _SavedQuestionsScreenState extends ConsumerState<SavedQuestionsScreen> {
  @override
  Widget build(BuildContext context) {
    final savedAsync = ref.watch(savedQuestionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Knowledge Vault'), centerTitle: true),
      body: savedAsync.when(
        data: (questions) {
          if (questions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_border_rounded,
                    size: 64,
                    color: Theme.of(context).dividerColor,
                  ),
                  const SizedBox(height: 16),
                  const Text('No saved questions yet'),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: questions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final question = questions[index];
              return _buildQuestionCard(question);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> question) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        title: Text(
          question['content'] ?? 'Question',
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Saved ${question['savedAt'] != null ? DateTime.parse(question['savedAt']).toString().split(' ')[0] : ''}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          const Divider(),
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (question['options'] is List)
                  ...(question['options'] as List).map<Widget>(
                    (opt) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            opt['text'] == question['correctAnswer'] ||
                                    opt['id'] ==
                                        question['correctAnswer'] // Adjust based on data
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            size: 16,
                            color:
                                opt['text'] == question['correctAnswer'] ||
                                    opt['id'] == question['correctAnswer']
                                ? Colors.green
                                : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(opt['text'] ?? '')),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                if (question['explanation'] != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Explanation: ${question['explanation']}'),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await ref
                            .read(savedServiceProvider)
                            .toggleSave(question['id']);
                        ref.invalidate(savedQuestionsProvider);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Removed from Vault')),
                          );
                        }
                      } catch (e) {
                        // error
                      }
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove from Vault'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
