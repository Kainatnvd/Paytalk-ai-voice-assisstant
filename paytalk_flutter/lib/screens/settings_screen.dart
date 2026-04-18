import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/bento_card.dart';
import '../services/api_service.dart';

/// Settings Screen — profile info, language toggle, and account management.
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
  String _language = 'EN';
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
        _language = (info['preferred_language'] ?? 'en') == 'ur' ? 'UR' : 'EN';
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
      backgroundColor: Colors.white,
      body: SafeArea(
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
                            .copyWith(color: Colors.indigo.shade300)),
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
                              color: AppColors.primaryContainer,
                              border: Border.all(
                                  color: AppColors.primary.withOpacity(0.2)),
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
                                        .copyWith(color: Colors.indigo.shade300)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('Premium',
                                style: AppTypography.labelMedium
                                    .copyWith(color: AppColors.primary, fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Language Toggle ──
                    BentoCard(
                      padding: const EdgeInsets.all(20),
                      borderRadius: 20,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.translate,
                                    color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 16),
                              Text('Language',
                                  style: AppTypography.headlineSmall
                                      .copyWith(fontSize: 16)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                _buildLangChip('EN', _language == 'EN'),
                                _buildLangChip('UR', _language == 'UR'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Menu Items ──
                    _buildMenuItem(Icons.security, 'Security', 'Biometric & PIN settings'),
                    _buildMenuItem(Icons.notifications_outlined, 'Notifications', 'Push & SMS alerts'),
                    _buildMenuItem(Icons.help_outline, 'Help & Support', 'FAQ & contact us'),
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
    );
  }

  Widget _buildLangChip(String label, bool isActive) {
    return GestureDetector(
      onTap: () => setState(() => _language = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: isActive ? Colors.white : Colors.indigo.shade300,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: BentoCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        glassBorder: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
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
                          .copyWith(color: Colors.indigo.shade300, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.indigo.shade200, size: 22),
          ],
        ),
      ),
    );
  }
}
