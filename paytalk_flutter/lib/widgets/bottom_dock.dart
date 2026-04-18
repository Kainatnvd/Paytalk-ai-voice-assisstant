import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Floating dock bottom navigation matching the wireframe dock-blur CSS.
/// Glassmorphic pill with elevated center mic FAB.
class AppFloatingDock extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AppFloatingDock({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 50,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(0, Icons.dashboard_rounded, 'Dashboard'),
          _buildDisabledNavItem(Icons.account_balance_wallet_rounded, 'Wallet'),
          _buildCenterMic(),
          _buildNavItem(2, Icons.history_rounded, 'History'),
          _buildNavItem(3, Icons.settings_rounded, 'Settings'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isActive = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Icon(
          icon,
          color: isActive ? AppColors.primary : Colors.indigo.shade200,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildDisabledNavItem(IconData icon, String label) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Icon(
        icon,
        color: Colors.grey.withOpacity(0.3),
        size: 26,
      ),
    );
  }

  Widget _buildCenterMic() {
    return GestureDetector(
      onTap: () => onTap(0), // Goes to dashboard (voice assistant)
      child: Container(
        width: 56,
        height: 56,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: AppColors.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.mic, color: Colors.white, size: 28),
      ),
    );
  }
}
