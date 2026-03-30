import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

class GdprService {
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  /// Export all user data (GDPR Article 20)
  Future<Map<String, dynamic>> exportUserData() async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/gdpr/export'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to export user data');
      }
    } catch (e) {
      debugPrint('Error exporting user data: $e');
      rethrow;
    }
  }

  /// Delete user account (GDPR Article 17)
  Future<Map<String, dynamic>> deleteAccount(String password) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/gdpr/delete'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Clear local storage after successful deletion
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        return data as Map<String, dynamic>;
      } else {
        throw Exception('Failed to delete account');
      }
    } catch (e) {
      debugPrint('Error deleting account: $e');
      rethrow;
    }
  }

  /// Anonymize user data
  Future<Map<String, dynamic>> anonymizeAccount() async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/gdpr/anonymize'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Clear local storage after anonymization
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        return data as Map<String, dynamic>;
      } else {
        throw Exception('Failed to anonymize account');
      }
    } catch (e) {
      debugPrint('Error anonymizing account: $e');
      rethrow;
    }
  }

  /// Get data processing activities
  Future<Map<String, dynamic>> getProcessingActivities() async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/gdpr/processing-activities'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get processing activities');
      }
    } catch (e) {
      debugPrint('Error getting processing activities: $e');
      rethrow;
    }
  }
}
