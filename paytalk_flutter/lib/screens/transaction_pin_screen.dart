import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/mesh_gradient_background.dart';
import '../services/api_service.dart';

class TransactionPinScreen extends StatefulWidget {
  final Map<String, dynamic> pendingAction;

  const TransactionPinScreen({super.key, required this.pendingAction});

  @override
  State<TransactionPinScreen> createState() => _TransactionPinScreenState();
}

class _TransactionPinScreenState extends State<TransactionPinScreen> {
  final ApiService _apiService = ApiService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  bool _isLoading = false;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _submitPin(String pin) async {
    setState(() => _isLoading = true);
    
    // We send the PIN as text to the voice processing endpoint
    final result = await _apiService.submitVoiceText(pin);

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['status'] == 'success') {
        final data = result['data'];
        final responseText = data['response_text'];
        
        // Check if we moved to AWAITING_OTP
        if (data['dialogue_state'] == 'AWAITING_OTP') {
           Navigator.of(context).pop(data); // Return data to dashboard to handle next state
        } else {
          // Stay on screen and show error/response
          if (data['response_audio'] != null) {
            final bytes = base64Decode(data['response_audio']);
            await _audioPlayer.play(BytesSource(bytes));
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(responseText)),
          );
          // Clear PIN on error
          for (var controller in _controllers) {
            controller.clear();
          }
          _focusNodes[0].requestFocus();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'PIN validation failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Security Verification'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: AnimatedGradientBlob(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 48),
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppColors.primaryGradient.createShader(bounds),
                child: const Icon(Icons.lock_outline, size: 80, color: Colors.white),
              ),
              const SizedBox(height: 32),
              Text(
                'Enter Transaction PIN',
                style: AppTypography.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Verify your transfer of PKR ${widget.pendingAction['amount']}',
                style: AppTypography.bodyLarge.copyWith(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              // PIN manual inputs
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _buildPinBox(index),
                )),
              ),
              
              const SizedBox(height: 48),
              
              if (_isLoading)
                const CircularProgressIndicator(color: AppColors.primary)
              else
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryButtonGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      String pin = _controllers.map((e) => e.text).join();
                      if (pin.length == 4) {
                        _submitPin(pin);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('Verify PIN',
                        style: AppTypography.headlineSmall.copyWith(color: Colors.white)),
                  ),
                ),
              
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel Transaction',
                    style: AppTypography.labelLarge.copyWith(color: AppColors.error)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinBox(int index) {
    return SizedBox(
      width: 60,
      height: 70,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        obscureText: true,
        maxLength: 1,
        style: AppTypography.headlineLarge.copyWith(color: AppColors.primary),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white.withOpacity(0.35),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.primary.withOpacity(0.6), width: 2),
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 3) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          
          // Auto-submit if last box is filled
          if (index == 3 && value.isNotEmpty) {
            String pin = _controllers.map((e) => e.text).join();
            if (pin.length == 4) {
              _submitPin(pin);
            }
          }
        },
      ),
    );
  }
}
