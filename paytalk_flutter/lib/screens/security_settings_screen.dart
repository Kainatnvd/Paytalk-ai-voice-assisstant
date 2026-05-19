import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/bento_card.dart';
import '../widgets/mesh_gradient_background.dart';

class SecuritySettingsScreen extends StatelessWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Security', style: AppTypography.headlineMedium),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedGradientBlob(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Account Security',
                style: AppTypography.displayLarge.copyWith(fontSize: 28)),
            const SizedBox(height: 8),
            Text('Manage your password and authentication methods.',
                style: AppTypography.bodyMedium),
            const SizedBox(height: 32),

            _buildSecurityOption(
              context,
              Icons.help_outline,
              'Forgot Password',
              'Recover your account if you have lost your credentials.',
              () => Navigator.pushNamed(context, '/forgot-password'),
            ),
            const SizedBox(height: 16),

            _buildSecurityOption(
              context,
              Icons.lock_reset,
              'Forgot PIN',
              'Recover your transaction PIN with your phone and CNIC.',
              () => Navigator.pushNamed(context, '/forgot-pin'),
            ),
            const SizedBox(height: 32),

            BentoCard(
              padding: const EdgeInsets.all(24),
              borderRadius: 24,
              child: Column(
                children: [
                  const Icon(Icons.support_agent, size: 48, color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text('Need Help?', style: AppTypography.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'If you are having trouble with your security settings, contact our team.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text('HELPLINE', style: AppTypography.caption.copyWith(letterSpacing: 2)),
                        const SizedBox(height: 4),
                        Text('0800-PAYTALK', 
                            style: AppTypography.headlineMedium.copyWith(color: AppColors.primary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSecurityOption(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: BentoCard(
        padding: const EdgeInsets.all(20),
        borderRadius: 20,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.headlineSmall.copyWith(fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: AppTypography.bodySmall.copyWith(color: Colors.grey[600])),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
