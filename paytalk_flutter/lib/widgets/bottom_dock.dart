import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Floating dock bottom navigation matching the wireframe dock-blur CSS.
/// Glassmorphic pill with inline center mic redirect button.
class AppFloatingDock extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  /// Global notifier to trigger mic scroll in DashboardScreen
  static final ValueNotifier<int> micScrollNotifier = ValueNotifier<int>(0);

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

  /// Inline mic button — redirects to Dashboard and scrolls to the actual mic
  Widget _buildCenterMic() {
    return GestureDetector(
      onTap: () {
        onTap(0); // Navigate to dashboard tab
        micScrollNotifier.value++; // Trigger scroll to mic viewport
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.mic, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}
