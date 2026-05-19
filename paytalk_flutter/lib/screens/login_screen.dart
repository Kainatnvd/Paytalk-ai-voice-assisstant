import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/mesh_gradient_background.dart';
import '../widgets/glass_card.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    if (_phoneController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await _apiService.login(
      _phoneController.text.trim(),
      _passwordController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (result['status'] == 'success') {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } else {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Access Denied'),
            content: Text(result['message'] ?? 'Invalid credentials'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedGradientBlob(
        child: Stack(
          children: [
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  // ── PayTalk Logo ──
                  _buildLogo(),
                  const SizedBox(height: 48),
                  // ── Glass Login Card ──
                  _buildLoginCard(),
                  const SizedBox(height: 32),
                  // ── Security Badges ──
                  _buildSecurityBadges(),
                  const SizedBox(height: 32),
                  // ── Footer ──
                  _buildFooter(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Hero(
                  tag: 'login_card',
                  child: GlassCard(
                    padding: const EdgeInsets.all(32.0),
                    borderRadius: 40.0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Secure Login',
                            style: AppTypography.displayLarge
                                .copyWith(fontSize: 40)),
                        const SizedBox(height: 8),
                        Text(
                          'Enter your credentials to access your secure conduit.',
                          style: AppTypography.bodyMedium,
                        ),
                        const SizedBox(height: 32),
                        Text('Phone number', style: AppTypography.labelSmall),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.phone_iphone,
                                color: AppColors.primary),
                            hintText: '03001234567',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                  color: AppColors.primary.withOpacity(0.1)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Password', style: AppTypography.labelSmall),
                            TextButton(
                              onPressed: () {},
                              child: Text('Forgot Password?',
                                  style: AppTypography.labelSmall
                                      .copyWith(color: AppColors.primary)),
                            ),
                          ],
                        ),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock,
                                color: AppColors.primary),
                            hintText: '••••••••••••',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                  color: AppColors.primary.withOpacity(0.1)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          width: double.infinity,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(32)),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('Access Vault',
                                          style: AppTypography.headlineMedium
                                              .copyWith(color: Colors.white)),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward,
                                          color: Colors.white),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  '© 2024 PAYTALK INTELLIGENCE SYSTEMS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC0C7DC),
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Text(
          'PayTalk',
          style: AppTypography.displayLarge
              .copyWith(color: const Color(0xFF1c1060), fontSize: 40),
        ),
        const SizedBox(height: 4),
        Text(
          'AI-POWERED VOICE BANKING',
          style: AppTypography.caption
              .copyWith(color: const Color(0xFF1c1060), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return GlassCard(
      borderRadius: 40,
      padding: const EdgeInsets.all(32),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.1),
          blurRadius: 64,
          offset: const Offset(0, 32),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ──
          Text(_isRegistering ? 'Create Account' : 'Secure Login',
              style: AppTypography.displayLarge
                  .copyWith(fontSize: 27, color: const Color(0xFF1c1060))),
          const SizedBox(height: 8),
          Text(
            _isRegistering
                ? 'Register to create your secure account.'
                : 'Enter your credentials to access your secure account.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: 32),

          if (_isRegistering) ...[
            Text('Full Name',
                style: AppTypography.labelLarge.copyWith(fontSize: 14)),
            const SizedBox(height: 8),
            _buildTextField(
                _nameController, Icons.person, 'John Doe', TextInputType.name),
            const SizedBox(height: 24),
            Text('CNIC (13 digits)',
                style: AppTypography.labelLarge.copyWith(fontSize: 14)),
            const SizedBox(height: 8),
            _buildTextField(_cnicController, Icons.credit_card, '4210112345678',
                TextInputType.number),
            const SizedBox(height: 24),
            Text('4-Digit PIN',
                style: AppTypography.labelLarge.copyWith(fontSize: 14)),
            const SizedBox(height: 8),
            _buildTextField(
                _pinController, Icons.pin, '1234', TextInputType.number),
            const SizedBox(height: 24),
          ],

          // ── Phone Field ──
          Text('Contact Number',
              style: AppTypography.labelLarge.copyWith(fontSize: 14)),
          const SizedBox(height: 8),
          _buildPhoneField(),
          const SizedBox(height: 24),

          // ── Password Field ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Password',
                  style: AppTypography.labelLarge.copyWith(fontSize: 14)),
              if (!_isRegistering)
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, '/forgot-password');
                  },
                  child: Text(
                    'Forgot Password?',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _buildPasswordField(),
          const SizedBox(height: 32),

          // ── Login Button ──
          _buildLoginButton(),
          const SizedBox(height: 24),

          // ── Divider ──
          Row(
            children: [
              Expanded(
                  child: Container(
                      height: 1, color: AppColors.primary.withOpacity(0.1))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'SIGN UP',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.onSurface.withOpacity(0.5),
                    fontSize: 10,
                  ),
                ),
              ),
              Expanded(
                  child: Container(
                      height: 1, color: AppColors.primary.withOpacity(0.1))),
            ],
          ),
          const SizedBox(height: 16),

          // ── Create Account Toggle ──
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                    _isRegistering
                        ? 'Already have an account? '
                        : 'New to PayTalk? ',
                    style: AppTypography.bodyMedium.copyWith(fontSize: 14)),
                GestureDetector(
                  onTap: () => setState(() => _isRegistering = !_isRegistering),
                  child: Text(
                    _isRegistering ? 'Login' : 'Create Account',
                    style: AppTypography.headlineSmall.copyWith(
                      color: AppColors.primary,
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                      decorationThickness: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneField() {
    return TextField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      style: AppTypography.bodyLarge.copyWith(color: AppColors.onSurface),
      decoration: InputDecoration(
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 12),
          child: Icon(Icons.phone_iphone, color: AppColors.primary, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 0),
        hintText: '+92 300 1234567',
        hintStyle: AppTypography.bodyLarge
            .copyWith(color: AppColors.primary.withOpacity(0.3)),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide:
              BorderSide(color: AppColors.primary.withOpacity(0.4), width: 2),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, IconData icon,
      String hint, TextInputType type) {
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
        hintStyle: AppTypography.bodyLarge
            .copyWith(color: AppColors.primary.withOpacity(0.3)),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide:
              BorderSide(color: AppColors.primary.withOpacity(0.4), width: 2),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: AppTypography.bodyLarge.copyWith(color: AppColors.onSurface),
      decoration: InputDecoration(
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 12),
          child: Icon(Icons.lock, color: AppColors.primary, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 0),
        suffixIcon: GestureDetector(
          onTap: () => setState(() => _obscurePassword = !_obscurePassword),
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: AppColors.primary.withOpacity(0.6),
              size: 20,
            ),
          ),
        ),
        suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 0),
        hintText: '••••••••••••',
        hintStyle: AppTypography.bodyLarge
            .copyWith(color: AppColors.primary.withOpacity(0.3)),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide:
              BorderSide(color: AppColors.primary.withOpacity(0.4), width: 2),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: AppColors.primaryButtonGradient,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_isRegistering ? 'Register' : 'Login',
                      style: AppTypography.headlineSmall
                          .copyWith(color: Colors.white)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward,
                      color: Colors.white, size: 20),
                ],
              ),
      ),
    );
  }

  Widget _buildSecurityBadges() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 24,
      runSpacing: 8,
      children: [
        _buildBadge(Icons.verified_user, 'END-TO-END ENCRYPTION'),
        _buildBadge(Icons.public, 'GLOBAL STANDARDS'),
      ],
    );
  }

  Widget _buildBadge(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.7), size: 18),
        const SizedBox(width: 6),
        Text(
          text,
          style: AppTypography.caption.copyWith(
            color: Colors.white.withOpacity(0.9),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.support_agent, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              'Helpline: 0800-PAYTALK',
              style: AppTypography.labelLarge
                  .copyWith(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '© 2026 PayTalk Intelligent Systems. All rights reserved.',
          style: AppTypography.caption.copyWith(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
