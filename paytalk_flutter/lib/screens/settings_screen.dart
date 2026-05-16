import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/bento_card.dart';
import '../widgets/mesh_gradient_background.dart';
import '../services/api_service.dart';

/// Settings Screen — profile info and account management.
/// Clean bento-style layout matching the Ethereal Professional design system.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _apiService = ApiService();
  String _userName = 'User';
  String _phone = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final info = await _apiService.getAccountInfo();
    final name = await _apiService.currentUserName;

    if (mounted) {
      setState(() {
        _userName = name ?? info['full_name'] ?? 'User';
        _phone = info['phone_number'] ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Logout', style: AppTypography.headlineMedium),
        content:
            Text('Are you sure you want to logout?', style: AppTypography.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: AppTypography.labelLarge.copyWith(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _apiService.logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/');
              }
            },
            child: Text('Logout',
                style: AppTypography.labelLarge.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: AnimatedGradientBlob(
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header ──
                      Text('Settings',
                          style: AppTypography.displayMedium.copyWith(fontSize: 28)),
                      const SizedBox(height: 4),
                      Text('Manage your account preferences.',
                          style: AppTypography.bodyMedium
                              .copyWith(color: AppColors.textMuted)),
                      const SizedBox(height: 32),

                    // ── Profile Card ──
                    BentoCard(
                      padding: const EdgeInsets.all(24),
                      borderRadius: 24,
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withOpacity(0.15),
                                  AppColors.accent.withOpacity(0.1),
                                ],
                              ),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.4),
                                  width: 1.5),
                            ),
                            child: Center(
                              child: Text(
                                _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                                style: AppTypography.headlineLarge
                                    .copyWith(color: AppColors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_userName,
                                    style: AppTypography.headlineSmall),
                                const SizedBox(height: 2),
                                Text(_phone,
                                    style: AppTypography.bodySmall
                                        .copyWith(color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: AppColors.accentGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('Premium',
                                style: AppTypography.labelMedium
                                    .copyWith(color: Colors.white, fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Menu Items ──
                    _buildMenuItem(
                      Icons.security, 
                      'Security', 
                      'PIN settings',
                      onTap: () {
                        Navigator.pushNamed(context, '/security-settings');
                      },
                    ),
                    _buildMenuItem(
                      Icons.notifications_outlined, 
                      'Notifications', 
                      'Push & SMS alerts',
                      onTap: () => Navigator.pushNamed(context, '/notification-settings'),
                    ),
                    _buildMenuItem(
                      Icons.help_outline, 
                      'Help & Support', 
                      'FAQ & contact us',
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            title: Text('Help & Support', style: AppTypography.headlineMedium, textAlign: TextAlign.center),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.support_agent, size: 64, color: AppColors.primary),
                                const SizedBox(height: 16),
                                Text('Contact PayTalk Team', style: AppTypography.headlineSmall),
                                const SizedBox(height: 8),
                                Text('If you have any issues, please call our 24/7 helpline below:', 
                                    textAlign: TextAlign.center, 
                                    style: AppTypography.bodyMedium),
                                const SizedBox(height: 24),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryContainer,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    children: [
                                      Text('0800-PAYTALK', 
                                          style: AppTypography.headlineMedium.copyWith(color: AppColors.primary)),
                                      const SizedBox(height: 4),
                                      Text('(0800-7298255)', 
                                          style: AppTypography.bodyMedium.copyWith(color: AppColors.primary)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Close',
                                    style: AppTypography.labelLarge.copyWith(color: AppColors.textMuted)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(Icons.info_outline, 'About PayTalk', 'Version 1.0.0'),
                    const SizedBox(height: 24),

                    // ── Logout Button ──
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _handleLogout,
                        icon: const Icon(Icons.logout, size: 20),
                        label: Text('Logout',
                            style: AppTypography.labelLarge
                                .copyWith(color: AppColors.error)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error.withOpacity(0.05),
                          foregroundColor: AppColors.error,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: BentoCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 16,
          glassBorder: false,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.12),
                      AppColors.accent.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTypography.headlineSmall.copyWith(fontSize: 15)),
                    Text(subtitle,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.indigo.shade200, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
