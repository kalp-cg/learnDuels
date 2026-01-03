import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

class SpectatorService {
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  /// Get list of spectatable duels
  Future<List<dynamic>> getSpectatableDuels({int limit = 20}) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/spectate/duels?limit=$limit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] as List<dynamic>;
      } else {
        throw Exception('Failed to get spectatable duels');
      }
    } catch (e) {
      debugPrint('Error getting spectatable duels: $e');
      rethrow;
    }
  }

  /// Get duel details for spectating
  Future<Map<String, dynamic>> getDuelDetails(
    int duelId,
    String socketId,
  ) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.get(
        Uri.parse(
          '${ApiConstants.baseUrl}/spectate/duels/$duelId?socketId=$socketId',
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
        throw Exception('Failed to get duel details');
      }
    } catch (e) {
      debugPrint('Error getting duel details: $e');
      rethrow;
    }
  }

  /// Get spectators for a duel
  Future<List<dynamic>> getSpectators(int duelId) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/spectate/duels/$duelId/spectators'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] as List<dynamic>;
      } else {
        throw Exception('Failed to get spectators');
      }
    } catch (e) {
      debugPrint('Error getting spectators: $e');
      rethrow;
    }
  }
}
