import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class QuestionsService {
  final ApiService _api = ApiService();

  /// Get access token from storage
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  /// Create a new question
  Future<Map<String, dynamic>> createQuestion(Map<String, dynamic> questionData) async {
    try {
      final token = await _getToken();
      final response = await _api.client.post(
        '/questions',
        data: questionData,
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
      );

      return response.data;
    } catch (e) {
      debugPrint('Error creating question: $e');
      rethrow;
    }
  }
}
