import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/spectator_service.dart';

final spectatorServiceProvider = Provider<SpectatorService>((ref) {
  return SpectatorService();
});

final activeDuelsProvider = FutureProvider.autoDispose<List<dynamic>>((
  ref,
) async {
  final service = ref.watch(spectatorServiceProvider);
  return service.getSpectatableDuels();
});
