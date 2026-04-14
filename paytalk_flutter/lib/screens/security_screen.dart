import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/bento_card.dart';

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Ambient Glows
          Positioned(
            top: 100,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.04),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 48),
                        _buildContextNotification(),
                        const SizedBox(height: 24),
                        _buildConfirmingText(),
                        const SizedBox(height: 48),
                        _buildOtpSection(),
                        const SizedBox(height: 64),
                        _buildBentoDetails(),
                        const SizedBox(height: 120),
                      ],
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: const DecorationImage(
                    image: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuC9sIVrVJgO15kU1MRUmnzakqDuGisfyzq_1NdsdCvtjwDFiYAvlkWfhd05sHrkhnAUrV7AcBpfn02t42w8WpjibthWbXhdFYspmQ1Cq6a0XKf6NVAPl-B5I9350LMp47KuaIn5bxJqcD4a9TdtY2Yj6IFfIJ-jerCapF4KDJmjoOm_fBmEQ6_aN3uopWVq0Mry0wP9RdppTAHsVpY3rian3ibnkWA-4FyAqrYb3kZp3yFvbHFrL2I11ZdJb-aQ5xw6212rUXbH0cE'),
                    fit: BoxFit.cover,
                  ),
                  border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                ),
              ),
              const SizedBox(width: 12),
              Text('PayTalk', style: AppTypography.headlineMedium.copyWith(color: AppColors.primary)),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.shield, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text('\$24,500.00', style: AppTypography.headlineLarge.copyWith(color: AppColors.primary, fontSize: 18)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContextNotification() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Text('HIGH VALUE TRANSACTION', style: AppTypography.labelSmall.copyWith(color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _buildConfirmingText() {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: AppTypography.displayLarge.copyWith(fontSize: 40),
            children: [
              const TextSpan(text: 'Confirming '),
              TextSpan(text: '\$5,200.00', style: const TextStyle(color: AppColors.primary)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Sending to Sophia Martinez for Real Estate Deposit.',
          style: AppTypography.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildOtpSection() {
    return Column(
      children: [
        Text('Please speak your 6-digit OTP', style: AppTypography.headlineMedium.copyWith(color: AppColors.primary)),
        const SizedBox(height: 8),
        Text('براہ کرم اپنا 6 ہندسوں کا OTP بولیں', style: AppTypography.urduText.copyWith(color: AppColors.primary.withOpacity(0.6))),
        const SizedBox(height: 48),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            bool isActive = index == 0;
            return Container(
              width: 48,
              height: 64,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isActive ? Colors.white : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isActive ? AppColors.primary : const Color(0xFFF1F5F9)),
                boxShadow: isActive ? [BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 10)] : null,
              ),
              child: Center(
                child: Text(
                  isActive ? '|' : '0',
                  style: AppTypography.displayLarge.copyWith(fontSize: 32, color: isActive ? AppColors.primary : const Color(0xFFE2E8F0)),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 64),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 180,
              height: 180,
              child: CircularProgressIndicator(
                value: 0.7,
                strokeWidth: 4,
                color: AppColors.primary,
                backgroundColor: const Color(0xFFF8FAFC),
              ),
            ),
            Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 30)],
              ),
              child: const Center(
                child: Icon(Icons.mic, color: Colors.white, size: 40),
              ),
            ),
            Positioned(
              bottom: -40,
              child: Column(
                children: [
                  Text('0:42', style: AppTypography.displayLarge.copyWith(fontSize: 20)),
                  Text('SECONDS LEFT', style: AppTypography.labelSmall.copyWith(fontSize: 8)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBentoDetails() {
    return Column(
      children: [
        BentoCard(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.verified_user, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SECURITY PROTOCOL', style: AppTypography.labelSmall.copyWith(fontSize: 8, color: AppColors.primary)),
                    Text('Voice Biomarker Active', style: AppTypography.headlineMedium.copyWith(fontSize: 18)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF8FAFC),
                  foregroundColor: Colors.grey,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 15)],
                ),
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Resend OTP', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
