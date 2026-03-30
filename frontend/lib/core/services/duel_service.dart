import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import 'api_service.dart';

final duelServiceProvider = Provider<DuelService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return DuelService(apiService.client);
});

class DuelService {
  final Dio _dio;

  DuelService(this._dio);

  // Get auth token helper
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  // Fetch categories/topics
  Future<List<dynamic>> getCategories() async {
    try {
      final token = await _getToken();
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/categories', // Adjust if needed
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data['data'] ?? [];
    } catch (e) {
      throw Exception('Failed to load categories');
    }
  }

  // Start a duel (matchmaking)
  Future<Map<String, dynamic>> startDuel(int categoryId) async {
    try {
      final token = await _getToken();
      final response = await _dio.post(
        ApiConstants.duelMatchmaking,
        data: {'categoryId': categoryId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data['data'];
    } catch (e) {
      throw Exception('Failed to start duel');
    }
  }

  // Create a duel challenge
  Future<Map<String, dynamic>> createDuelChallenge(
    int opponentId,
    int categoryId,
  ) async {
    try {
      final token = await _getToken();
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/duels',
        data: {
          'opponentId': opponentId,
          'categoryId': categoryId,
          'difficultyId': 1, // Default to medium/1 for now
          'questionCount': 5,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data['data'];
    } catch (e) {
      throw Exception('Failed to create duel challenge');
    }
  }

  // Get duel details
  Future<Map<String, dynamic>> getDuel(int duelId) async {
    try {
      final token = await _getToken();
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/duels/$duelId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data['data'];
    } catch (e) {
      throw Exception('Failed to load duel');
    }
  }

  // Submit answer
  Future<void> submitAnswer(
    int duelId,
    int questionId,
    String selectedOption,
  ) async {
    try {
      final token = await _getToken();
      await _dio.post(
        '${ApiConstants.baseUrl}/duels/$duelId/questions/$questionId/answer',
        data: {'selectedOption': selectedOption},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (e) {
      // Ignore error for now or log it
      debugPrint('Error submitting answer: $e');
    }
  }
}
