import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../core/services/api_service.dart';

// Provider for fetching topics
final topicsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ApiService();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('accessToken');

  try {
    final response = await api.client.get(
      '/topics',
      options: token != null
          ? Options(headers: {'Authorization': 'Bearer $token'})
          : null,
    );

    if (response.data['success'] == true) {
      return response.data['data'] ?? [];
    }
    return [];
  } catch (e) {
    debugPrint('Error fetching topics: $e');
    return [];
  }
});

class InterestsScreen extends ConsumerStatefulWidget {
  const InterestsScreen({super.key});

  @override
  ConsumerState<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends ConsumerState<InterestsScreen> {
  final Set<int> _selectedTopics = {};
  bool _isLoading = false;

  Future<void> _saveInterests() async {
    if (_selectedTopics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select at least one topic',
            style: GoogleFonts.firaCode(),
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

      // Save interests to user profile
      await api.client.put(
        '/users/me',
        data: {'interests': _selectedTopics.toList()},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      // Mark onboarding as complete
      await prefs.setBool('onboardingComplete', true);

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } catch (e) {
      debugPrint('Error saving interests: $e');
      // Still navigate on error (soft fail)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboardingComplete', true);
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topicsAsync = ref.watch(topicsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        color: AppTheme.background,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.interests_rounded,
                          color: AppTheme.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'What interests you?',
                              style: GoogleFonts.firaCode(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Select topics to personalize your experience',
                              style: GoogleFonts.firaCode(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Topic selection count
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_selectedTopics.length} selected',
                    style: GoogleFonts.firaCode(
                      fontSize: 13,
                      color: _selectedTopics.isNotEmpty
                          ? AppTheme.primary
                          : AppTheme.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Topics grid
                Expanded(
                  child: topicsAsync.when(
                    data: (topics) {
                      if (topics.isEmpty) {
                        return Center(
                          child: Text(
                            'No topics available',
                            style: GoogleFonts.firaCode(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        );
                      }
                      return GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 1.5,
                            ),
                        itemCount: topics.length,
                        itemBuilder: (context, index) {
                          final topic = topics[index];
                          return _buildTopicCard(topic);
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    ),
                    error: (e, s) => Center(
                      child: Text(
                        'Error loading topics',
                        style: GoogleFonts.firaCode(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Continue button
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _selectedTopics.isNotEmpty
                        ? AppTheme.primary
                        : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _selectedTopics.isNotEmpty
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
                      onTap: _isLoading ? null : _saveInterests,
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
                                    Text(
                                      'Continue',
                                      style: GoogleFonts.firaCode(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: _selectedTopics.isNotEmpty
                                            ? Colors.white
                                            : AppTheme.textMuted,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      color: _selectedTopics.isNotEmpty
                                          ? Colors.white
                                          : AppTheme.textMuted,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Skip button
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('onboardingComplete', true);
                      if (!context.mounted) return;

                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/home',
                        (route) => false,
                      );
                    },
                    child: Text(
                      'Skip for now',
                      style: GoogleFonts.firaCode(
                        color: AppTheme.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopicCard(Map<String, dynamic> topic) {
    final id = topic['id'] as int;
    final name = topic['name'] ?? 'Unknown';
    final isSelected = _selectedTopics.contains(id);

    // Icon mapping
    IconData icon;
    Color iconColor;

    final nameLower = name.toString().toLowerCase();
    if (nameLower.contains('science') ||
        nameLower.contains('physics') ||
        nameLower.contains('chemistry')) {
      icon = Icons.science_rounded;
      iconColor = const Color(0xFF9C27B0);
    } else if (nameLower.contains('math')) {
      icon = Icons.calculate_rounded;
      iconColor = const Color(0xFF2196F3);
    } else if (nameLower.contains('history')) {
      icon = Icons.history_edu_rounded;
      iconColor = const Color(0xFF795548);
    } else if (nameLower.contains('geography') || nameLower.contains('world')) {
      icon = Icons.public_rounded;
      iconColor = const Color(0xFF4CAF50);
    } else if (nameLower.contains('sports')) {
      icon = Icons.sports_soccer_rounded;
      iconColor = const Color(0xFFFF5722);
    } else if (nameLower.contains('music') || nameLower.contains('art')) {
      icon = Icons.music_note_rounded;
      iconColor = const Color(0xFFE91E63);
    } else if (nameLower.contains('tech') ||
        nameLower.contains('computer') ||
        nameLower.contains('programming')) {
      icon = Icons.computer_rounded;
      iconColor = const Color(0xFF00BCD4);
    } else if (nameLower.contains('literature') ||
        nameLower.contains('english')) {
      icon = Icons.menu_book_rounded;
      iconColor = const Color(0xFF607D8B);
    } else if (nameLower.contains('movie') ||
        nameLower.contains('film') ||
        nameLower.contains('entertainment')) {
      icon = Icons.movie_rounded;
      iconColor = const Color(0xFFFFC107);
    } else {
      icon = Icons.category_rounded;
      iconColor = AppTheme.accent;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedTopics.remove(id);
          } else {
            _selectedTopics.add(id);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? iconColor.withValues(alpha: 0.15)
              : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? iconColor
                : AppTheme.border.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(
                        alpha: isSelected ? 0.2 : 0.1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: GoogleFonts.firaCode(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? iconColor : AppTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: iconColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
