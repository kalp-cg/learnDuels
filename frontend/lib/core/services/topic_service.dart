import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class TopicService {
  final ApiService _api = ApiService();

  /// Get access token from storage
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  /// Get all topics (flat or tree structure)
  Future<List<Map<String, dynamic>>> getTopics({bool asTree = false}) async {
    try {
      final token = await _getToken();
      final response = await _api.client.get(
        '/topics',
        queryParameters: {'asTree': asTree},
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
      );

      return List<Map<String, dynamic>>.from(response.data['data']);
    } catch (e) {
      debugPrint('Error getting topics: $e');
      rethrow;
    }
  }

  /// Get popular topics
  Future<List<Map<String, dynamic>>> getPopularTopics({int limit = 10}) async {
    try {
      final token = await _getToken();
      final response = await _api.client.get(
        '/topics/popular',
        queryParameters: {'limit': limit},
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
      );

      return List<Map<String, dynamic>>.from(response.data['data']);
    } catch (e) {
      debugPrint('Error getting popular topics: $e');
      rethrow;
    }
  }

  /// Search topics
  Future<List<Map<String, dynamic>>> searchTopics(String query) async {
    try {
      final token = await _getToken();
      final response = await _api.client.get(
        '/topics/search',
        queryParameters: {'q': query},
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
      );

      return List<Map<String, dynamic>>.from(response.data['data']);
    } catch (e) {
      debugPrint('Error searching topics: $e');
      rethrow;
    }
  }

  /// Get topic by ID with details
  Future<Map<String, dynamic>> getTopicById(int id) async {
    try {
      final token = await _getToken();
      final response = await _api.client.get(
        '/topics/$id',
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
      );

      return response.data['data'];
    } catch (e) {
      debugPrint('Error getting topic: $e');
      rethrow;
    }
  }

  /// Get subtopics of a topic
  Future<List<Map<String, dynamic>>> getSubtopics(int parentId) async {
    try {
      final token = await _getToken();
      final response = await _api.client.get(
        '/topics/$parentId/subtopics',
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
      );

      return List<Map<String, dynamic>>.from(response.data['data']);
    } catch (e) {
      debugPrint('Error getting subtopics: $e');
      rethrow;
    }
  }
}
