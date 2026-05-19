import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';

/// Full API service integrating with PayTalk FastAPI backend.
/// Endpoints: /auth, /account, /transaction, /voice
class ApiService extends ChangeNotifier {
  /// Static notifier to trigger global UI refreshes
  static final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);

  ApiService() {
    // When the static notifier changes, notify all instance listeners
    refreshNotifier.addListener(notifyListeners);
  }

  @override
  void dispose() {
    refreshNotifier.removeListener(notifyListeners);
    super.dispose();
  }

  /// Increment this to notify all listeners watching refreshNotifier
  static void refresh() {
    refreshNotifier.value++;
  }
  // Use http://10.0.2.2:8000 for Android Emulator
  // Use http://localhost:8000 for Web / Windows / iOS Simulator
  static const String baseUrl = 'http://127.0.0.1:8000';

  // ── Auth ────────────────────────────────────────────────────────────

  /// POST /auth/login → { access_token, user: { user_id, full_name, ... } }
  Future<Map<String, dynamic>> login(String phone, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        body: json.encode({
          'phone_number': phone,
          'password': password,
        }),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access_token']);
        await prefs.setString('user_id', data['user']['user_id']);
        await prefs.setString(
            'user_name', data['user']['full_name'] ?? 'User');
        await prefs.setString(
            'user_phone', data['user']['phone_number'] ?? '');
        
        refresh(); // Notify listeners that user state has changed
        return {'status': 'success', 'data': data};
      } else {
        return {
          'status': 'error',
          'message': _parseError(data['detail']) ?? 'Login failed'
        };
      }
    } on TimeoutException {
      return {'status': 'error', 'message': 'Server is not responding. Please check your connection and try again.'};
    } catch (e) {
      return {'status': 'error', 'message': 'Connection error: $e'};
    }
  }

  /// POST /auth/register → { user_id, full_name, phone_number, ... }
  Future<Map<String, dynamic>> register(
      String name, String phone, String cnic, String password, String pin) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        body: json.encode({
          'full_name': name,
          'phone_number': phone,
          'cnic': cnic,
          'password': password,
          'pin': pin,
        }),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        // After registration, automatically login
        return await login(phone, password);
      } else {
        return {
          'status': 'error',
          'message': _parseError(data['detail']) ?? 'Registration failed'
        };
      }
    } on TimeoutException {
      return {'status': 'error', 'message': 'Server is not responding. Please check your connection and try again.'};
    } catch (e) {
      return {'status': 'error', 'message': 'Connection error: $e'};
    }
  }

  /// POST /auth/reset-password
  Future<Map<String, dynamic>> resetPassword(String phone, String cnic, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/reset-password'),
        body: json.encode({
          'phone_number': phone,
          'cnic': cnic,
          'new_password': newPassword,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'status': 'success', 'message': data['message']};
      } else {
        return {
          'status': 'error',
          'message': _parseError(data['detail']) ?? 'Password reset failed'
        };
      }
    } catch (e) {
      return {'status': 'error', 'message': 'Connection error: $e'};
    }
  }

  /// POST /auth/reset-pin
  Future<Map<String, dynamic>> resetPin(String phone, String cnic, String newPin) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/reset-pin'),
        body: json.encode({
          'phone_number': phone,
          'cnic': cnic,
          'new_pin': newPin,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'status': 'success', 'message': data['message']};
      } else {
        return {
          'status': 'error',
          'message': _parseError(data['detail']) ?? 'PIN reset failed'
        };
      }
    } catch (e) {
      return {'status': 'error', 'message': 'Connection error: $e'};
    }
  }

  /// POST /auth/logout
  Future<void> logout() async {
    try {
      final headers = await _getAuthHeaders();
      if (headers != null) {
        await http.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: headers,
        );
      }
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /// POST /auth/otp/send
  Future<Map<String, dynamic>> sendOtp(String phoneNumber) async {
    try {
      final headers = await _getAuthHeaders();
      if (headers == null) {
        return {'status': 'error', 'message': 'Not logged in'};
      }
      final response = await http.post(
        Uri.parse('$baseUrl/auth/otp/send'),
        headers: headers,
        body: json.encode({'phone_number': phoneNumber}),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'status': 'error', 'message': 'Failed to send OTP'};
    } catch (e) {
      return {'status': 'error', 'message': 'Connection error: $e'};
    }
  }

  /// POST /auth/otp/verify
  Future<Map<String, dynamic>> verifyOtp(
      String userId, String otpCode) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/otp/verify'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': userId, 'otp_code': otpCode}),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'status': 'success', 'data': data};
      }
      return {
        'status': 'error',
        'message': _parseError(data['detail']) ?? 'OTP verification failed'
      };
    } catch (e) {
      return {'status': 'error', 'message': 'Connection error: $e'};
    }
  }

  // ── Account ─────────────────────────────────────────────────────────

  /// GET /account/balance → { account_number, balance, currency, owner }
  Future<Map<String, dynamic>> getBalance() async {
    try {
      final headers = await _getAuthHeaders();
      if (headers == null) {
        return {'status': 'error', 'message': 'Not logged in'};
      }
      final response = await http.get(
        Uri.parse('$baseUrl/account/balance'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'status': 'error', 'message': 'Failed to fetch balance'};
    } catch (e) {
      return {'status': 'error', 'message': 'Connection error: $e'};
    }
  }

  /// GET /account/history?limit=N → List of transactions
  Future<List<Transaction>> getTransactions({int limit = 10}) async {
    try {
      final headers = await _getAuthHeaders();
      if (headers == null) return [];

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';

      final response = await http.get(
        Uri.parse('$baseUrl/account/history?limit=$limit'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data
            .map((item) => Transaction.fromJson(item, userId))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// GET /account/info → UserResponse
  Future<Map<String, dynamic>> getAccountInfo() async {
    try {
      final headers = await _getAuthHeaders();
      if (headers == null) {
        return {'status': 'error', 'message': 'Not logged in'};
      }
      final response = await http.get(
        Uri.parse('$baseUrl/account/info'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'status': 'error', 'message': 'Failed to fetch account info'};
    } catch (e) {
      return {'status': 'error', 'message': 'Connection error: $e'};
    }
  }

  // ── Transaction ─────────────────────────────────────────────────────

  /// POST /transaction/transfer → initiate_transfer
  Future<Map<String, dynamic>> initiateTransfer(
      String recipientName, double amount) async {
    try {
      final headers = await _getAuthHeaders();
      if (headers == null) {
        return {'status': 'error', 'message': 'Not logged in'};
      }
      final response = await http.post(
        Uri.parse('$baseUrl/transaction/transfer'),
        headers: headers,
        body: json.encode({
          'recipient_name_query': recipientName,
          'amount': amount,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Connection error: $e'};
    }
  }

  /// POST /transaction/confirm
  Future<Map<String, dynamic>> confirmTransfer({
    required String recipientAccount,
    required String recipientName,
    required double amount,
    required String otpCode,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      if (headers == null) {
        return {'status': 'error', 'message': 'Not logged in'};
      }
      final response = await http.post(
        Uri.parse('$baseUrl/transaction/confirm'),
        headers: headers,
        body: json.encode({
          'recipient_account': recipientAccount,
          'recipient_name': recipientName,
          'amount': amount,
          'otp_code': otpCode,
        }),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        refresh(); // Refresh balance and history across screens
        return {'status': 'success', 'data': data};
      } else {
        return {
          'status': 'error',
          'message': _parseError(data['detail']) ?? 'Confirmation failed'
        };
      }
    } catch (e) {
      return {'status': 'error', 'message': 'Connection error: $e'};
    }
  }

  String? _parseError(dynamic detail) {
    if (detail == null) return null;
    if (detail is String) return detail;
    if (detail is List) {
      try {
        // Return the first validation message if available
        return detail[0]['msg'] ?? detail.toString();
      } catch (_) {
        return detail.toString();
      }
    }
    return detail.toString();
  }

  /// GET /transaction/{id} → single transaction
  Future<Map<String, dynamic>> getTransaction(int transactionId) async {
    try {
      final headers = await _getAuthHeaders();
      if (headers == null) {
        return {'status': 'error', 'message': 'Not logged in'};
      }
      final response = await http.get(
        Uri.parse('$baseUrl/transaction/$transactionId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'status': 'error', 'message': 'Transaction not found'};
    } catch (e) {
      return {'status': 'error', 'message': 'Connection error: $e'};
    }
  }

  // ── Voice ───────────────────────────────────────────────────────────

  /// POST /voice/process (multipart audio file) → VoiceProcessResponse
  Future<Map<String, dynamic>> processVoice(String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) {
        return {'status': 'error', 'message': 'Not logged in'};
      }

      final nonce = await _getVoiceNonce();
      if (nonce == null) {
        return {'status': 'error', 'message': 'Failed to secure connection (nonce error)'};
      }

      var request = http.MultipartRequest(
          'POST', Uri.parse('$baseUrl/voice/process'));
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['nonce'] = nonce;

      if (kIsWeb) {
        final response = await http.get(Uri.parse(filePath));
        final bytes = response.bodyBytes;
        request.files.add(http.MultipartFile.fromBytes(
          'audio',
          bytes,
          filename: 'command.wav',
        ));
      } else {
        request.files
            .add(await http.MultipartFile.fromPath('audio', filePath));
      }

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
          'message':
              'Voice processing failed: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'status': 'error', 'message': 'Connection error: $e'};
    }
  }

  /// POST /voice/process-text (JSON) → VoiceProcessResponse
  Future<Map<String, dynamic>> submitVoiceText(String text) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) {
        return {'status': 'error', 'message': 'Not logged in'};
      }

      final nonce = await _getVoiceNonce();
      if (nonce == null) {
        return {'status': 'error', 'message': 'Failed to secure connection (nonce error)'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/voice/process-text'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'text': text,
          'nonce': nonce,
        }),
      );

      if (response.statusCode == 200) {
        return {
          'status': 'success',
          'data': json.decode(response.body),
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'status': 'error',
          'message': errorData['detail'] ?? 'Text processing failed',
        };
      }
    } catch (e) {
      return {'status': 'error', 'message': 'Connection error: $e'};
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  Future<String?> _getVoiceNonce() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/voice/nonce'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['nonce'];
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, String>?> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return null;
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<String?> get currentUserName async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name');
  }

  Future<String?> get currentUserId async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  Future<bool> get isLoggedIn async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') != null;
  }
}
