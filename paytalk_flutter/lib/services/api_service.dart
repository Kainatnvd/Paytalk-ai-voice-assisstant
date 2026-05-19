import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';

class ApiService {
  // Use http://10.0.2.2:8000 for Android Emulator, http://localhost:8000 for Web/iOS
  static const String baseUrl = 'http://localhost:8000'; 

  Future<Map<String, dynamic>> login(String phone, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        body: json.encode({
          'phone_number': phone,
          'password': password,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access_token']);
        await prefs.setString('user_id', data['user']['user_id']);
        return {'status': 'success', 'data': data};
      } else {
        return {'status': 'error', 'message': data['detail'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'status': 'error', 'message': 'Connection error: $e'};
    }
  }

  Future<Map<String, dynamic>?> getHeader() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return null;
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> getBalance() async {
    try {
      final headers = await getHeader();
      if (headers == null) return {'status': 'error', 'message': 'Not logged in'};

      final response = await http.get(
        Uri.parse('$baseUrl/account/balance'),
        headers: headers.cast<String, String>(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'status': 'error', 'message': 'Failed to fetch balance'};
    } catch (e) {
      return {'status': 'error', 'message': 'Connection error'};
    }
  }

  Future<List<Transaction>> getTransactions() async {
    try {
      final headers = await getHeader();
      if (headers == null) return [];

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';

      final response = await http.get(
        Uri.parse('$baseUrl/account/history?limit=10'),
        headers: headers.cast<String, String>(),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((item) => Transaction.fromJson(item, userId)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> processVoice(String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) return {'status': 'error', 'message': 'Not logged in'};

      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/voice/process'));
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('audio', filePath));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return {
          'status': 'success',
          'data': json.decode(response.body),
        };
      } else {
        return {
          'status': 'error',
          'message': 'Voice processing failed: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'status': 'error', 'message': 'Connection error: $e'};
    }
  }
  
  Future<void> logout() async {

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

