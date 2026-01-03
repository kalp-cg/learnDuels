import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/custom_button.dart';

class CreateChallengeScreen extends ConsumerStatefulWidget {
  const CreateChallengeScreen({super.key});

  @override
  ConsumerState<CreateChallengeScreen> createState() =>
      _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends ConsumerState<CreateChallengeScreen> {
  int? _selectedOpponentId;
  int? _selectedQuestionSetId;
  String _challengeType = 'ASYNC';
  bool _isLoading = false;

  Future<void> _createChallenge() async {
    if (_selectedOpponentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an opponent')),
      );
      return;
    }

    if (_selectedQuestionSetId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a quiz')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // TODO: Call challenge service to create challenge
      // await ref.read(challengeServiceProvider).createChallenge(...)

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Challenge sent!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Create Challenge')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Opponent',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  // TODO: Add user search/selection widget
                  const Text('User selection coming soon...'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Quiz',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  // TODO: Add quiz selection widget
                  const Text('Quiz selection coming soon...'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Challenge Type',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  RadioListTile<String>(
                    title: const Text('Async (Take turns)'),
                    subtitle: const Text(
                      'You each complete the quiz separately',
                    ),
                    value: 'ASYNC',
                    groupValue: _challengeType,
                    toggleable: false,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _challengeType = value);
                      }
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Instant (Real-time)'),
                    subtitle: const Text('Compete live at the same time'),
                    value: 'INSTANT',
                    groupValue: _challengeType,
                    toggleable: false,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _challengeType = value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: 'Send Challenge',
            isLoading: _isLoading,
            onPressed: _createChallenge,
          ),
        ],
      ),
    );
  }
}
