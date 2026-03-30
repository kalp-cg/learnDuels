import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/duel_provider.dart';

class RoomCreationScreen extends ConsumerStatefulWidget {
  final int categoryId;

  const RoomCreationScreen({super.key, required this.categoryId});

  @override
  ConsumerState<RoomCreationScreen> createState() => _RoomCreationScreenState();
}

class _RoomCreationScreenState extends ConsumerState<RoomCreationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _roomCodeController = TextEditingController();
  int _questionCount = 7; // Default 7 questions

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomCode = ref.watch(roomCodeProvider);

    // Listen for duel start
    ref.listen(duelStateProvider, (previous, next) {
      next.whenData((data) {
        if (!mounted) return;
        if (data != null && data['questions'] != null) {
          Navigator.pushReplacementNamed(context, '/duel');
        }
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Match'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Create Room'),
            Tab(text: 'Join Room'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Create Room Tab
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (roomCode == null) ...[
                  const Icon(
                    Icons.add_circle_outline,
                    size: 80,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Create a private room and share the code with your friend.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 32),

                  // Question Count Selection
                  const Text(
                    'Number of Questions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    children: [5, 7, 10, 15].map((count) {
                      final isSelected = _questionCount == count;
                      return ChoiceChip(
                        label: Text('$count'),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _questionCount = count);
                          }
                        },
                        selectedColor: AppTheme.primary,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppTheme.background
                              : AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      ref
                          .read(duelStateProvider.notifier)
                          .createRoom(
                            widget.categoryId,
                            questionCount: _questionCount,
                          );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('Generate Room Code'),
                  ),
                ] else ...[
                  const Text(
                    'Room Code',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primary, width: 2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          roomCode,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: roomCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Code copied to clipboard'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Waiting for opponent to join...'),
                ],
              ],
            ),
          ),

          // Join Room Tab
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.login, size: 80, color: AppTheme.secondary),
                const SizedBox(height: 24),
                const Text(
                  'Enter the 6-character room code shared by your friend.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _roomCodeController,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'ENTER CODE',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  maxLength: 6,
                  style: const TextStyle(fontSize: 24, letterSpacing: 4),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    final code = _roomCodeController.text.trim().toUpperCase();
                    if (code.length == 6) {
                      ref.read(duelStateProvider.notifier).joinRoom(code);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    backgroundColor: AppTheme.secondary,
                  ),
                  child: const Text('Join Room'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
