import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import 'api_service.dart';

final leaderboardServiceProvider = Provider<LeaderboardService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return LeaderboardService(apiService.client);
});

class LeaderboardService {
  final Dio _dio;

  LeaderboardService(this._dio);

  Future<Map<String, dynamic>?> getGlobalLeaderboard({
    String period = 'weekly',
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      final response = await _dio.get(
        '${ApiConstants.leaderboard}/global',
        queryParameters: {'period': period, 'page': page, 'limit': limit},
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
      );

      if (response.data['success']) {
        return response.data;
      }
      return _getDummyLeaderboard();
    } catch (e) {
      debugPrint('Error getting leaderboard: $e');
      return _getDummyLeaderboard();
    }
  }

  Map<String, dynamic> _getDummyLeaderboard() {
    return {
      'success': true,
      'data': List.generate(20, (index) {
        return {
          'id': index + 1,
          'username': 'Player ${index + 1}',
          'avatar_url': 'https://i.pravatar.cc/150?u=${index + 1}',
          'xp': 5000 - (index * 150),
          'rank': index + 1,
          'level': 20 - (index ~/ 2),
        };
      }),
    };
  }

  Future<Map<String, dynamic>?> getUserRanking() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      if (token == null) return _getDummyUserRanking();

      final response = await _dio.get(
        '${ApiConstants.leaderboard}/my/rank',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.data['success']) {
        return response.data['data'];
      }
      return _getDummyUserRanking();
    } catch (e) {
      debugPrint('Error getting user ranking: $e');
      return _getDummyUserRanking();
    }
  }

  Map<String, dynamic> _getDummyUserRanking() {
    return {
      'rank': 42,
      'username': 'You',
      'xp': 1250,
      'totalUsers': 1000,
      'percentile': 95.8,
    };
  }

  Future<Map<String, dynamic>?> getUserStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      if (token == null) return _getDummyUserStats();

      final response = await _dio.get(
        '${ApiConstants.leaderboard}/my/stats',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.data['success']) {
        return response.data['data'];
      }
      return _getDummyUserStats();
    } catch (e) {
      debugPrint('Error getting user stats: $e');
      return _getDummyUserStats();
    }
  }

  Map<String, dynamic> _getDummyUserStats() {
    return {
      'total_xp': 1250,
      'current_streak': 5,
      'games_played': 42,
      'win_rate': 65.5,
      'rank': 42,
    };
  }
}
