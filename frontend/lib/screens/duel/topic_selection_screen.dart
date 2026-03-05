import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/topic_service.dart';
import '../../providers/duel_provider.dart';
import 'room_creation_screen.dart';

final topicsProvider = FutureProvider<List<dynamic>>((ref) async {
  final service = TopicService();
  final topics = await service.getTopics();
  return topics;
});

final difficultiesProvider = FutureProvider<List<String>>((ref) async {
  return ['EASY', 'MEDIUM', 'HARD'];
});

class TopicSelectionScreen extends ConsumerStatefulWidget {
  final int? opponentId;
  final String? opponentName;

  const TopicSelectionScreen({super.key, this.opponentId, this.opponentName});

  @override
  ConsumerState<TopicSelectionScreen> createState() =>
      _TopicSelectionScreenState();
}

class _TopicSelectionScreenState extends ConsumerState<TopicSelectionScreen> {
  String selectedDifficulty = 'MEDIUM';
  int? selectedCategoryId;
  bool _isStarting = false;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(topicsProvider);
    final difficultiesAsync = ref.watch(difficultiesProvider);
    final isChallengeMode = widget.opponentId != null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          isChallengeMode ? 'Challenge ${widget.opponentName}' : 'New Game',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              shape: BoxShape.circle,
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: Theme.of(context).iconTheme.color,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(topicsProvider);
                  ref.invalidate(difficultiesProvider);
                },
                color: Theme.of(context).colorScheme.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Difficulty Section
                      _buildSectionTitle('Difficulty'),
                      const SizedBox(height: 16),
                      difficultiesAsync.when(
                        data: (difficulties) =>
                            _buildDifficultySelector(difficulties),
                        loading: () => _buildLoadingSkeleton(height: 50),
                        error: (_, _) => const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 32),

                      // Topics Section
                      _buildSectionTitle('Select Topic'),
                      const SizedBox(height: 16),
                      categoriesAsync.when(
                        data: (categories) {
                          if (categories.isEmpty) {
                            return _buildEmptyState();
                          }
                          return _buildCategoriesGrid(categories);
                        },
                        loading: () => _buildGridSkeleton(),
                        error: (err, stack) => _buildErrorState(ref),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Action Bar
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildDifficultySelector(List<String> difficulties) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: difficulties.map((difficulty) {
          final isSelected = selectedDifficulty == difficulty;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => selectedDifficulty = difficulty),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  difficulty,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoriesGrid(List<dynamic> categories) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return _buildCategoryCard(category);
      },
    );
  }

  Widget _buildCategoryCard(dynamic category) {
    final categoryId = category['id'] as int?;
    final isSelected = selectedCategoryId == categoryId;

    return GestureDetector(
      onTap: () => setState(() => selectedCategoryId = categoryId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
              : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getCategoryIcon(category['name'] ?? ''),
                size: 32,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).iconTheme.color?.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                category['name'] ?? 'Unknown',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).textTheme.bodyLarge?.color,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (category['questionCount'] != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${category['questionCount']} Questions',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final isChallengeMode = widget.opponentId != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: (selectedCategoryId != null && !_isStarting)
                  ? _handleStartDuel
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                disabledBackgroundColor: Theme.of(context).disabledColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isStarting
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.onPrimary,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      isChallengeMode ? 'Send Challenge' : 'Quick Match',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
          if (!isChallengeMode) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: (selectedCategoryId != null && !_isStarting)
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RoomCreationScreen(
                              categoryId: selectedCategoryId!,
                            ),
                          ),
                        );
                      }
                    : null,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                child: Text(
                  'Play with Friend',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleStartDuel() async {
    if (selectedCategoryId == null) return;

    setState(() => _isStarting = true);
    try {
      if (widget.opponentId != null) {
        // Challenge Mode
        await ref
            .read(duelStateProvider.notifier)
            .sendChallenge(widget.opponentId!, selectedCategoryId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Challenge sent to ${widget.opponentName}!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Go back to friends list
        }
      } else {
        // Quick Match Mode (Socket Queue)
        ref.read(duelStateProvider.notifier).joinQueue(selectedCategoryId!);

        // Wait a bit or Just Navigate - DuelScreen will show waiting state
        if (mounted) {
          Navigator.pushNamed(context, '/duel');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start game: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isStarting = false);
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.category_outlined,
            size: 64,
            color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No topics available',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(WidgetRef ref) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load topics',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              ref.invalidate(topicsProvider);
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton({double height = 100}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildGridSkeleton() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => _buildLoadingSkeleton(),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('science')) return Icons.science_rounded;
    if (name.contains('math')) return Icons.calculate_rounded;
    if (name.contains('history')) return Icons.history_edu_rounded;
    if (name.contains('geography')) return Icons.public_rounded;
    if (name.contains('literature')) return Icons.menu_book_rounded;
    if (name.contains('art')) return Icons.palette_rounded;
    if (name.contains('music')) return Icons.music_note_rounded;
    if (name.contains('sport')) return Icons.sports_rounded;
    if (name.contains('tech') || name.contains('computer')) {
      return Icons.computer_rounded;
    }
    if (name.contains('biology')) return Icons.biotech_rounded;
    if (name.contains('chemistry')) return Icons.science_rounded;
    if (name.contains('physics')) return Icons.lightbulb_rounded;
    return Icons.category_rounded;
  }
}
