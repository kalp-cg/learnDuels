import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../core/services/api_service.dart';

// Provider for fetching available questions
final availableQuestionsProvider = FutureProvider.autoDispose<List<dynamic>>((
  ref,
) async {
  final api = ApiService();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('accessToken');

  if (token == null) return [];

  try {
    final response = await api.client.get(
      '/questions',
      queryParameters: {'status': 'published', 'limit': 100},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    if (response.data['success'] == true) {
      return response.data['data'] ?? [];
    }
    return [];
  } catch (e) {
    debugPrint('Error fetching questions: $e');
    return [];
  }
});

class CreateQuizSetScreen extends ConsumerStatefulWidget {
  const CreateQuizSetScreen({super.key});

  @override
  ConsumerState<CreateQuizSetScreen> createState() =>
      _CreateQuizSetScreenState();
}

class _CreateQuizSetScreenState extends ConsumerState<CreateQuizSetScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final Set<int> _selectedQuestionIds = {};
  bool _isPublic = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _createQuizSet() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a name for the quiz',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    if (_selectedQuestionIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select at least one question',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final api = ApiService();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      await api.client.post(
        '/quizzes',
        data: {
          'name': _nameController.text.trim(),
          'description': _descController.text.trim(),
          'questionIds': _selectedQuestionIds.toList(),
          'visibility': _isPublic ? 'public' : 'private',
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.success,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Quiz Created!',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your quiz set "${_nameController.text}" with ${_selectedQuestionIds.length} questions has been created successfully.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Go back
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Done',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to create quiz: $e',
              style: GoogleFonts.outfit(),
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final questionsAsync = ref.watch(availableQuestionsProvider);

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
          'Create Quiz Set',
          style: GoogleFonts.outfit(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        color: AppTheme.background,
        child: Column(
          children: [
            // Form inputs
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name field
                  TextField(
                    controller: _nameController,
                    style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Quiz Name',
                      labelStyle: GoogleFonts.outfit(color: AppTheme.textMuted),
                      hintText: 'e.g., Science Basics Quiz',
                      hintStyle: GoogleFonts.outfit(
                        color: AppTheme.textMuted.withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description field
                  TextField(
                    controller: _descController,
                    style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Description (optional)',
                      labelStyle: GoogleFonts.outfit(color: AppTheme.textMuted),
                      hintText: 'A short description of this quiz...',
                      hintStyle: GoogleFonts.outfit(
                        color: AppTheme.textMuted.withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Visibility toggle
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isPublic
                                  ? Icons.public_rounded
                                  : Icons.lock_rounded,
                              color: _isPublic
                                  ? AppTheme.success
                                  : AppTheme.textMuted,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _isPublic ? 'Public Quiz' : 'Private Quiz',
                              style: GoogleFonts.outfit(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _isPublic,
                          onChanged: (v) => setState(() => _isPublic = v),
                          activeThumbColor: AppTheme.success,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Selection count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Questions',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedQuestionIds.isNotEmpty
                              ? AppTheme.primary.withValues(alpha: 0.2)
                              : AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${_selectedQuestionIds.length} selected',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _selectedQuestionIds.isNotEmpty
                                ? AppTheme.primary
                                : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Questions list
            Expanded(
              child: questionsAsync.when(
                data: (questions) {
                  if (questions.isEmpty) {
                    return Center(
                      child: Text(
                        'No questions available',
                        style: GoogleFonts.outfit(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: questions.length,
                    itemBuilder: (context, index) {
                      final q = questions[index];
                      final id = q['id'] as int;
                      final isSelected = _selectedQuestionIds.contains(id);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedQuestionIds.remove(id);
                            } else {
                              _selectedQuestionIds.add(id);
                            }
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primary.withValues(alpha: 0.1)
                                : AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.border.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isSelected,
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selectedQuestionIds.add(id);
                                    } else {
                                      _selectedQuestionIds.remove(id);
                                    }
                                  });
                                },
                                activeColor: AppTheme.primary,
                              ),
                              Expanded(
                                child: Text(
                                  q['content'] ??
                                      q['questionText'] ??
                                      'Question',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    color: AppTheme.textPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  q['difficulty'] ?? 'medium',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
                error: (e, s) => Center(
                  child: Text(
                    'Error loading questions',
                    style: GoogleFonts.outfit(color: AppTheme.textSecondary),
                  ),
                ),
              ),
            ),

            // Create button
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _selectedQuestionIds.isNotEmpty
                      ? AppTheme.primary
                      : AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _selectedQuestionIds.isNotEmpty
                      ? [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isLoading ? null : _createQuizSet,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Center(
                        child: _isLoading
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
                                  Icon(
                                    Icons.add_box_rounded,
                                    color: _selectedQuestionIds.isNotEmpty
                                        ? Colors.white
                                        : AppTheme.textMuted,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Create Quiz Set',
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: _selectedQuestionIds.isNotEmpty
                                          ? Colors.white
                                          : AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
