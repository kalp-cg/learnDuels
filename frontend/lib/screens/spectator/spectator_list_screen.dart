import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/spectator_provider.dart';
import 'spectator_screen.dart';

class SpectatorListScreen extends ConsumerWidget {
  const SpectatorListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duelsAsync = ref.watch(activeDuelsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Live Duels')),
      body: duelsAsync.when(
        data: (duels) {
          if (duels.isEmpty) {
            return const Center(child: Text('No active duels at the moment.'));
          }
          return ListView.builder(
            itemCount: duels.length,
            itemBuilder: (context, index) {
              final duel = duels[index];
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  leading: const Icon(Icons.sports_esports),
                  title: Text(
                    '${duel['creator']['username']} vs ${duel['opponent']['username']}',
                  ),
                  subtitle: Text('Status: ${duel['status']}'),
                  trailing: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SpectatorScreen(
                            duelId: duel['id'],
                            roomId:
                                duel['roomCode'], // Assuming roomCode is available
                          ),
                        ),
                      );
                    },
                    child: const Text('Watch'),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
