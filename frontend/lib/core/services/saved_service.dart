import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

final savedServiceProvider = Provider<SavedService>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return SavedService(apiService.client);
});

class SavedService {
  final Dio _dio;

  SavedService(this._dio);

  Future<Map<String, dynamic>> toggleSave(int questionId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    final response = await _dio.post(
      '/saved/toggle',
      data: {'questionId': questionId},
      options: Options(
        headers: token != null ? {'Authorization': 'Bearer $token'} : null,
      ),
    );
    // Response format: { message: "...", isSaved: true/false }
    return response.data;
  }

  Future<Map<String, dynamic>> getSavedQuestions({
    int page = 1,
    int limit = 20,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    final response = await _dio.get(
      '/saved?page=$page&limit=$limit',
      options: Options(
        headers: token != null ? {'Authorization': 'Bearer $token'} : null,
      ),
    );
    // Response format: { data: [...], pagination: {...} }
    return response.data;
  }
}
