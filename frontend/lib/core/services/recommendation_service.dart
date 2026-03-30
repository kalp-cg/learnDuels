import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

class RecommendationService {
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  /// Get personalized user recommendations
  Future<List<dynamic>> getUserRecommendations({int limit = 10}) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/recommendations/users?limit=$limit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] as List<dynamic>;
      } else {
        throw Exception('Failed to get recommendations');
      }
    } catch (e) {
      debugPrint('Error getting user recommendations: $e');
      rethrow;
    }
  }

  /// Get topic recommendations based on user activity
  Future<List<dynamic>> getTopicRecommendations({int limit = 5}) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.get(
        Uri.parse(
          '${ApiConstants.baseUrl}/recommendations/topics?limit=$limit',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] as List<dynamic>;
      } else {
        throw Exception('Failed to get topic recommendations');
      }
    } catch (e) {
      debugPrint('Error getting topic recommendations: $e');
      rethrow;
    }
  }

  /// Get question set recommendations
  Future<List<dynamic>> getQuestionSetRecommendations({int limit = 10}) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.get(
        Uri.parse(
          '${ApiConstants.baseUrl}/recommendations/question-sets?limit=$limit',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] as List<dynamic>;
      } else {
        throw Exception('Failed to get question set recommendations');
      }
    } catch (e) {
      debugPrint('Error getting question set recommendations: $e');
      rethrow;
    }
  }
}
