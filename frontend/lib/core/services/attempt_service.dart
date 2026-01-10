import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AttemptService {
  final ApiService _api = ApiService();

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  Future<Map<String, dynamic>> startPracticeAttempt(
    int topicId,
    String difficulty, {
    int limit = 10,
  }) async {
    final token = await _getToken();
    final response = await _api.client.post(
      '/attempts/practice',
      data: {'topicId': topicId, 'difficulty': difficulty, 'limit': limit},
      options: Options(
        headers: token != null ? {'Authorization': 'Bearer $token'} : null,
      ),
    );
    return response.data['data'];
  }

  Future<Map<String, dynamic>> submitAnswer(
    int attemptId,
    int questionId,
    int answerIndex,
  ) async {
    final token = await _getToken();
    final response = await _api.client.post(
      '/attempts/$attemptId/answer',
      data: {'questionId': questionId, 'answerIndex': answerIndex},
      options: Options(
        headers: token != null ? {'Authorization': 'Bearer $token'} : null,
      ),
    );
    return response.data['data'];
  }

  Future<Map<String, dynamic>> completeAttempt(int attemptId) async {
    final token = await _getToken();
    final response = await _api.client.post(
      '/attempts/$attemptId/complete',
      options: Options(
        headers: token != null ? {'Authorization': 'Bearer $token'} : null,
      ),
    );
    return response.data['data'];
  }
}
