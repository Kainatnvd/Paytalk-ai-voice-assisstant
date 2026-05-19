import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/login_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/forgot_pin_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/transaction_otp_screen.dart';
import 'screens/history_screen.dart';
import 'screens/security_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/security_settings_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'widgets/bottom_dock.dart';
import 'theme/app_colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const PayTalkApp());
}

class PayTalkApp extends StatelessWidget {
  const PayTalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PayTalk AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        fontFamily: 'Inter',
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/forgot-pin': (context) => const ForgotPinScreen(),
        '/dashboard': (context) => const NavigationShell(),
        '/security': (context) => const SecurityScreen(),
        '/security-settings': (context) => const SecuritySettingsScreen(),
        '/notification-settings': (context) => const NotificationSettingsScreen(),
      },
    );
  }
}

/// Navigation shell with floating dock bottom bar.
/// Hosts: Dashboard (voice), Wallet/History, History, Settings
class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key});

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),  // Tab 0: Dashboard (Voice AI hub)
    HistoryScreen(),    // Tab 1: Wallet / Account History
    HistoryScreen(),    // Tab 2: History (same view, active history tab)
    SettingsScreen(),   // Tab 3: Settings
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: AppFloatingDock(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
