import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/mesh_gradient_background.dart';
import '../widgets/glass_card.dart';
import '../services/api_service.dart';

class ForgotPinScreen extends StatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cnicController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _obscurePin = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _cnicController.dispose();
    _newPinController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    final phone = _phoneController.text.trim();
    final cnic = _cnicController.text.trim();
    final newPin = _newPinController.text.trim();

    if (phone.isEmpty || cnic.isEmpty || newPin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill in all fields'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (newPin.length != 4 || int.tryParse(newPin) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PIN must be exactly 4 digits'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await _apiService.resetPin(phone, cnic, newPin);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction PIN updated successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Reset Failed',
              style: AppTypography.headlineMedium.copyWith(color: AppColors.primary)),
          content: Text(result['message'] ?? 'Unable to reset PIN.',
              style: AppTypography.bodyMedium),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Retry',
                  style: AppTypography.labelLarge.copyWith(color: AppColors.primary)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedGradientBlob(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GlassCard(
                borderRadius: 40,
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Reset PIN',
                        style: AppTypography.displayLarge.copyWith(fontSize: 32)),
                    const SizedBox(height: 8),
                    Text(
                      'Verify your identity using your phone number and CNIC to create a new 4-digit transaction PIN.',
                      style: AppTypography.bodyMedium,
                    ),
                    const SizedBox(height: 32),

                    Text('Phone number',
                        style: AppTypography.labelLarge.copyWith(fontSize: 14)),
                    const SizedBox(height: 8),
                    _buildTextField(_phoneController, Icons.phone_iphone, '+92 300 1234567', TextInputType.phone),
                    const SizedBox(height: 24),

                    Text('CNIC (13 digits)',
                        style: AppTypography.labelLarge.copyWith(fontSize: 14)),
                    const SizedBox(height: 8),
                    _buildTextField(_cnicController, Icons.credit_card, '4210112345678', TextInputType.number),
                    const SizedBox(height: 24),

                    Text('New 4-Digit PIN',
                        style: AppTypography.labelLarge.copyWith(fontSize: 14)),
                    const SizedBox(height: 8),
                    _buildPinField(),
                    const SizedBox(height: 32),

                    _buildResetButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, IconData icon, String hint, TextInputType type) {
    return TextField(
      controller: controller,
      keyboardType: type,
      style: AppTypography.bodyLarge.copyWith(color: AppColors.onSurface),
      decoration: InputDecoration(
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 12),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 0),
        hintText: hint,
        hintStyle: AppTypography.bodyLarge.copyWith(color: AppColors.textMuted.withOpacity(0.4)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.35),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.5), width: 2),
        ),
      ),
    );
  }

  Widget _buildPinField() {
    return TextField(
      controller: _newPinController,
      obscureText: _obscurePin,
      keyboardType: TextInputType.number,
      maxLength: 4,
      style: AppTypography.bodyLarge.copyWith(color: AppColors.onSurface),
      decoration: InputDecoration(
        counterText: '',
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 12),
          child: Icon(Icons.pin, color: AppColors.primary, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 0),
        suffixIcon: GestureDetector(
          onTap: () => setState(() => _obscurePin = !_obscurePin),
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              _obscurePin ? Icons.visibility_off : Icons.visibility,
              color: AppColors.primary.withOpacity(0.6),
              size: 20,
            ),
          ),
        ),
        suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 0),
        hintText: '••••',
        hintStyle: AppTypography.bodyLarge.copyWith(color: AppColors.textMuted.withOpacity(0.4)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.35),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.5), width: 2),
        ),
      ),
    );
  }

  Widget _buildResetButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: AppColors.primaryButtonGradient,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: AppColors.accent.withOpacity(0.12),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleReset,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Update PIN',
                      style: AppTypography.headlineSmall.copyWith(color: Colors.white)),
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                ],
              ),
      ),
    );
  }
}
