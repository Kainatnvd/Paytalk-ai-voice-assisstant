import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/glass_card.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TransactionOtpScreen extends StatefulWidget {
  final Map<String, dynamic> pendingAction;

  const TransactionOtpScreen({super.key, required this.pendingAction});

  @override
  State<TransactionOtpScreen> createState() => _TransactionOtpScreenState();
}

class _TransactionOtpScreenState extends State<TransactionOtpScreen> {
  final ApiService _apiService = ApiService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isRecording = false;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _submitOtp(String otp) async {
    setState(() => _isLoading = true);
    
    final result = await _apiService.confirmTransfer(
      recipientAccount: widget.pendingAction['recipient_account'],
      recipientName: widget.pendingAction['recipient_name'],
      amount: double.tryParse(widget.pendingAction['amount'].toString()) ?? 0.0,
      otpCode: otp,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['status'] == 'success') {
        _showSuccessDialog(result['data']['message']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      }
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Success!', style: AppTypography.headlineMedium),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: AppTypography.bodyMedium),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // dialog
              Navigator.of(context).pop(true); // back to dashboard + refresh
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        _processVoice(path);
      }
    } else {
      if (await _audioRecorder.hasPermission()) {
        String? path;
        if (!kIsWeb) {
          final directory = await getTemporaryDirectory();
          path = p.join(directory.path, 'otp_confirm.wav');
        }
        await _audioRecorder.start(const RecordConfig(), path: path ?? '');
        setState(() => _isRecording = true);
      }
    }
  }

  Future<void> _processVoice(String filePath) async {
    setState(() => _isLoading = true);
    final result = await _apiService.processVoice(filePath);
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (result['status'] == 'success') {
        final data = result['data'];
        final responseText = data['response_text'];
        
        // If the backend processed the transfer (state reset), it will return a success template
        if (responseText.contains('successful') || responseText.contains('sucessful') || responseText.contains('kamyabi')) {
          _showSuccessDialog(responseText);
        } else {
          // Play audio response (Assistant might be asking to repeat or showing error)
          if (data['response_audio'] != null) {
            final bytes = base64Decode(data['response_audio']);
            await _audioPlayer.play(BytesSource(bytes));
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(responseText)),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Transaction'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 48),
            Text(
              'Confirm Transfer',
              style: AppTypography.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'PKR ${widget.pendingAction['amount']} to ${widget.pendingAction['recipient_name']}',
              style: AppTypography.bodyLarge.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 48),
            
            // OTP manual inputs
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) => _buildOtpBox(index)),
            ),
            
            const SizedBox(height: 48),
            
            if (_isLoading)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: () {
                  String otp = _controllers.map((e) => e.text).join();
                  if (otp.length == 6) {
                    _submitOtp(otp);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Confirm Manually'),
              ),
            
            const SizedBox(height: 40),
            const Text('OR USE VOICE', style: TextStyle(color: Colors.grey, letterSpacing: 1.2, fontSize: 12)),
            const SizedBox(height: 24),
            
            // Mic button for "Yes Confirm"
            GestureDetector(
              onTap: _toggleRecording,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording ? Colors.redAccent : AppColors.primaryContainer,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ]
                ),
                child: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  color: _isRecording ? Colors.white : AppColors.primary,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isRecording ? 'Listening for "Yes Confirm"...' : 'Say "Yes Confirm"',
              style: AppTypography.bodySmall,
            ),

            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _resendOtp,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Resend OTP Code'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resendOtp() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('user_phone') ?? '';
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User phone not found')));
      return;
    }

    setState(() => _isLoading = true);
    final result = await _apiService.sendOtp(phone);
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'OTP resent successfully')),
      );
    }
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 45,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: AppTypography.headlineMedium,
        decoration: InputDecoration(
          counterText: '',
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }
}
