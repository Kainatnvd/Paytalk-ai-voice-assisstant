import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/bento_card.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _pushNotifications = true;
  bool _smsAlerts = true;
  bool _emailReports = false;
  bool _marketingEmails = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Notifications', style: AppTypography.headlineMedium),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notification Settings',
                style: AppTypography.displayLarge.copyWith(fontSize: 28)),
            const SizedBox(height: 8),
            Text('Choose how you want to be alerted about your transactions and account activity.',
                style: AppTypography.bodyMedium),
            const SizedBox(height: 32),

            _buildToggleItem(
              'Push Notifications',
              'Receive instant alerts for every transaction',
              Icons.notifications_active_outlined,
              _pushNotifications,
              (val) => setState(() => _pushNotifications = val),
            ),
            const SizedBox(height: 16),
            _buildToggleItem(
              'SMS Alerts',
              'Get legacy SMS messages for high-value transfers',
              Icons.sms_outlined,
              _smsAlerts,
              (val) => setState(() => _smsAlerts = val),
            ),
            const SizedBox(height: 16),
            _buildToggleItem(
              'Email Monthly Reports',
              'Detailed statement sent to your inbox each month',
              Icons.email_outlined,
              _emailReports,
              (val) => setState(() => _emailReports = val),
            ),
            const SizedBox(height: 16),
            _buildToggleItem(
              'Promotions & News',
              'Updates on new features and seasonal offers',
              Icons.card_giftcard_outlined,
              _marketingEmails,
              (val) => setState(() => _marketingEmails = val),
            ),
            
            const SizedBox(height: 40),
            
            BentoCard(
              padding: const EdgeInsets.all(24),
              borderRadius: 24,
              child: Column(
                children: [
                  const Icon(Icons.security_update_good, size: 48, color: Colors.green),
                  const SizedBox(height: 16),
                  Text('Stay Informed', style: AppTypography.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Critical security alerts cannot be disabled to ensure your account safety.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleItem(String title, String subtitle, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return BentoCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      borderRadius: 20,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.headlineSmall.copyWith(fontSize: 16)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTypography.bodySmall.copyWith(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withOpacity(0.2),
          ),
        ],
      ),
    );
  }
}
