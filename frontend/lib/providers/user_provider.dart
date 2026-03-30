import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/user_service.dart';
import '../core/services/leaderboard_service.dart';

final userProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((
  ref,
) async {
  final service = ref.watch(userServiceProvider);
  return await service.getProfile();
});

final otherUserProfileProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, int>((ref, userId) async {
      final service = ref.watch(userServiceProvider);
      return await service.getUserById(userId);
    });

final userStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((
  ref,
) async {
  final service = ref.watch(leaderboardServiceProvider);
  return await service.getUserStats();
});
final otherUserStatsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, int>((ref, userId) async {
      // TODO: Implement getUserStatsById in UserService if needed.
      // For now, we might not have an endpoint for other user's detailed stats like accuracy.
      // But we can fetch basic stats if the API supports it.
      // Let's assume we only show basic profile info for others for now, or add the endpoint.
      return null;
    });
final globalLeaderboardProvider = FutureProvider.autoDispose<List<dynamic>>((
  ref,
) async {
  final service = ref.watch(leaderboardServiceProvider);
  final result = await service.getGlobalLeaderboard(limit: 5);
  return result?['data'] ?? [];
});
