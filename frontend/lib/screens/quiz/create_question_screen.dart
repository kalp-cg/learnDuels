import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/topic_service.dart';
import '../../providers/questions_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../core/theme.dart';

final topicsProvider = FutureProvider<List<dynamic>>((ref) async {
  final service = TopicService();
  final topics = await service.getTopics();
  return topics;
});

final difficultiesProvider = FutureProvider<List<dynamic>>((ref) async {
  return [
    {'id': 1, 'name': 'Easy'},
    {'id': 2, 'name': 'Medium'},
    {'id': 3, 'name': 'Hard'},
  ];
});

class CreateQuestionScreen extends ConsumerStatefulWidget {
  const CreateQuestionScreen({super.key});

  @override
  ConsumerState<CreateQuestionScreen> createState() =>
      _CreateQuestionScreenState();
}

class _CreateQuestionScreenState extends ConsumerState<CreateQuestionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final _optionAController = TextEditingController();
  final _optionBController = TextEditingController();
  final _optionCController = TextEditingController();
  final _optionDController = TextEditingController();

  String? _selectedCorrectOption;
  int? _selectedTopicId;
  int? _selectedDifficultyId;

  final List<String> _options = ['A', 'B', 'C', 'D'];

  @override
  void dispose() {
    _questionController.dispose();
    _optionAController.dispose();
    _optionBController.dispose();
    _optionCController.dispose();
    _optionDController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedTopicId == null ||
          _selectedDifficultyId == null ||
          _selectedCorrectOption == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select all dropdown fields',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
            ),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }

      final success = await ref
          .read(createQuestionControllerProvider.notifier)
          .createQuestion(
            questionText: _questionController.text,
            optionA: _optionAController.text,
            optionB: _optionBController.text,
            optionC: _optionCController.text,
            optionD: _optionDController.text,
            correctOption: _selectedCorrectOption!,
            categoryId: _selectedTopicId!,
            difficultyId: _selectedDifficultyId!,
          );

      if (success && mounted) {
        // Show success dialog then navigate to home
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
                  'Question Added!',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your question has been added to our knowledge base. It will appear in duels and practice mode!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '+10 Reputation earned!',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.tertiary,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context); // Close dialog
                          // Stay on the page to add another question
                          _questionController.clear();
                          _optionAController.clear();
                          _optionBController.clear();
                          _optionCController.clear();
                          _optionDController.clear();
                          setState(() {
                            _selectedCorrectOption = null;
                            _selectedTopicId = null;
                            _selectedDifficultyId = null;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Add Another',
                          style: GoogleFonts.outfit(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primary, AppTheme.primaryDark],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context); // Close dialog
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/home',
                                (route) => false,
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Center(
                                child: Text(
                                  'Go Home',
                                  style: GoogleFonts.outfit(
                                    color: AppTheme.background,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      } else if (mounted) {
        final error = ref.read(createQuestionControllerProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed: $error',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topicsAsync = ref.watch(topicsProvider);
    final difficultiesAsync = ref.watch(difficultiesProvider);
    final state = ref.watch(createQuestionControllerProvider);
    final isLoading = state.isLoading;

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
          'Contribute Question',
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  child: Column(
                    children: [
                      Icon(
                        Icons.lightbulb_rounded,
                        size: 40,
                        color: AppTheme.tertiary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Help grow the knowledge base!',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add a new question to challenge other players',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Question field
                CustomTextField(
                  label: 'Question',
                  hint: 'Enter your question here (min 5 characters)...',
                  controller: _questionController,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length < 5)
                      return 'Question must be at least 5 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Topics Dropdown
                _buildDropdownLabel('Topic'),
                const SizedBox(height: 8),
                topicsAsync.when(
                  data: (topics) => _buildDropdown<int>(
                    value: _selectedTopicId,
                    hint: 'Select a topic',
                    items: topics.map<DropdownMenuItem<int>>((t) {
                      return DropdownMenuItem<int>(
                        value: t['id'],
                        child: Text(
                          t['name'],
                          style: GoogleFonts.outfit(
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedTopicId = val),
                  ),
                  loading: () => _buildLoadingDropdown(),
                  error: (e, s) => _buildErrorText('Error loading topics'),
                ),
                const SizedBox(height: 20),

                // Difficulty Dropdown
                _buildDropdownLabel('Difficulty'),
                const SizedBox(height: 8),
                difficultiesAsync.when(
                  data: (diffs) => _buildDropdown<int>(
                    value: _selectedDifficultyId,
                    hint: 'Select difficulty',
                    items: diffs.map<DropdownMenuItem<int>>((d) {
                      Color diffColor;
                      if (d['id'] == 1) {
                        diffColor = AppTheme.success;
                      } else if (d['id'] == 2) {
                        diffColor = AppTheme.tertiary;
                      } else {
                        diffColor = AppTheme.secondary;
                      }

                      return DropdownMenuItem<int>(
                        value: d['id'],
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: diffColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              d['name'],
                              style: GoogleFonts.outfit(
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setState(() => _selectedDifficultyId = val),
                  ),
                  loading: () => _buildLoadingDropdown(),
                  error: (e, s) =>
                      _buildErrorText('Error loading difficulties'),
                ),
                const SizedBox(height: 28),

                // Options Section
                _buildSectionTitle('Answer Options'),
                const SizedBox(height: 16),

                CustomTextField(
                  label: 'Option A',
                  controller: _optionAController,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  prefixIcon: Icons.looks_one_rounded,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Option B',
                  controller: _optionBController,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  prefixIcon: Icons.looks_two_rounded,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Option C',
                  controller: _optionCController,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  prefixIcon: Icons.looks_3_rounded,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Option D',
                  controller: _optionDController,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  prefixIcon: Icons.looks_4_rounded,
                ),
                const SizedBox(height: 20),

                // Correct Option
                _buildDropdownLabel('Correct Answer'),
                const SizedBox(height: 8),
                _buildDropdown<String>(
                  value: _selectedCorrectOption,
                  hint: 'Select the correct option',
                  items: _options
                      .map(
                        (o) => DropdownMenuItem(
                          value: o,
                          child: Text(
                            'Option $o',
                            style: GoogleFonts.outfit(
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) =>
                      setState(() => _selectedCorrectOption = val),
                ),

                const SizedBox(height: 36),

                // Submit Button
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isLoading ? null : _submit,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Center(
                          child: isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: AppTheme.background,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.upload_rounded,
                                      color: AppTheme.background,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Submit Question',
                                      style: GoogleFonts.outfit(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.background,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
      ),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        hint: Text(hint, style: GoogleFonts.outfit(color: AppTheme.textMuted)),
        items: items,
        onChanged: onChanged,
        dropdownColor: AppTheme.surfaceLight,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppTheme.textMuted,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontSize: 15),
      ),
    );
  }

  Widget _buildLoadingDropdown() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: AppTheme.primary,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorText(String text) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Text(text, style: GoogleFonts.outfit(color: AppTheme.error)),
      ),
    );
  }
}
