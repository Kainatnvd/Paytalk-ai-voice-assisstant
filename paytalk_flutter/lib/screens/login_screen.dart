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
                children: [
                  Text(
                    'PayTalk',
                    style: AppTypography.displayLarge.copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'NEXT-GEN FINANCIAL LEDGER',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.onSurfaceVariant.withOpacity(0.7),
                      letterSpacing: 2.0,
                    ),
                  ),
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
                        Text('Secure Login', style: AppTypography.displayLarge.copyWith(fontSize: 40)),
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
                            prefixIcon: const Icon(Icons.phone_iphone, color: AppColors.primary),
                            hintText: '03001234567',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: AppColors.primary.withOpacity(0.1)),
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
                              child: Text('Forgot Password?', style: AppTypography.labelSmall.copyWith(color: AppColors.primary)),
                            ),
                          ],
                        ),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock, color: AppColors.primary),
                            hintText: '••••••••••••',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: AppColors.primary.withOpacity(0.1)),
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                            ),
                            child: _isLoading 
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Access Vault', style: AppTypography.headlineMedium.copyWith(color: Colors.white)),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward, color: Colors.white),
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
}

