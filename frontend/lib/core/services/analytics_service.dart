import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

class AnalyticsService {
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  /// Get dashboard statistics
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/analytics/dashboard'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get dashboard stats');
      }
    } catch (e) {
      debugPrint('Error getting dashboard stats: $e');
      rethrow;
    }
  }

  /// Get Daily Active Users data
  Future<List<dynamic>> getDailyActiveUsers({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not authenticated');

      final end = endDate ?? DateTime.now();
      final start = startDate ?? end.subtract(const Duration(days: 30));

      final response = await http.get(
        Uri.parse(
          '${ApiConstants.baseUrl}/analytics/dau?startDate=${start.toIso8601String()}&endDate=${end.toIso8601String()}',
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
        throw Exception('Failed to get DAU data');
      }
    } catch (e) {
      debugPrint('Error getting DAU: $e');
      rethrow;
    }
  }

  /// Get challenge statistics
  Future<Map<String, dynamic>> getChallengeStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not authenticated');

      final end = endDate ?? DateTime.now();
      final start = startDate ?? end.subtract(const Duration(days: 30));

      final response = await http.get(
        Uri.parse(
          '${ApiConstants.baseUrl}/analytics/challenges?startDate=${start.toIso8601String()}&endDate=${end.toIso8601String()}',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get challenge stats');
      }
    } catch (e) {
      debugPrint('Error getting challenge stats: $e');
      rethrow;
    }
  }

  /// Get quiz completion statistics
  Future<Map<String, dynamic>> getQuizStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not authenticated');

      final end = endDate ?? DateTime.now();
      final start = startDate ?? end.subtract(const Duration(days: 30));

      final response = await http.get(
        Uri.parse(
          '${ApiConstants.baseUrl}/analytics/quizzes?startDate=${start.toIso8601String()}&endDate=${end.toIso8601String()}',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get quiz stats');
      }
    } catch (e) {
      debugPrint('Error getting quiz stats: $e');
      rethrow;
    }
  }

  /// Get popular topics
  Future<List<dynamic>> getPopularTopics({
    int limit = 10,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not authenticated');

      final end = endDate ?? DateTime.now();
      final start = startDate ?? end.subtract(const Duration(days: 30));

      final response = await http.get(
        Uri.parse(
          '${ApiConstants.baseUrl}/analytics/topics/popular?limit=$limit&startDate=${start.toIso8601String()}&endDate=${end.toIso8601String()}',
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
        throw Exception('Failed to get popular topics');
      }
    } catch (e) {
      debugPrint('Error getting popular topics: $e');
      rethrow;
    }
  }
}
