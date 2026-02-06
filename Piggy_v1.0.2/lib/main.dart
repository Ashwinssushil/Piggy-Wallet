import 'package:flutter/material.dart';
import 'login.dart';
import 'home.dart';
import 'authentication.dart';
import 'package:flutter/services.dart';
import 'database.dart';

// Global flag to prevent auth checks during critical operations
class AppState {
  static bool isImportingData = false;
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      // Clear authentication state when app goes to background
      AuthService.clearAuthenticationState();
    } else if (state == AppLifecycleState.resumed) {
      // Skip auth check if we're currently importing data
      if (AppState.isImportingData) {
        return;
      }

      // Check authentication when app resumes
      final currentRoute = _navigatorKey.currentState?.context != null
          ? ModalRoute.of(_navigatorKey.currentState!.context)?.settings.name
          : null;

      // Only check auth if we're not already on login page and user is not authenticated
      if (currentRoute != '/login' && !AuthService.isUserAuthenticated()) {
        try {
          final isAuthEnabled = await AuthService.isAuthEnabled();
          final isPinSetup = await AuthService.isPinSetup();

          if (isAuthEnabled && isPinSetup) {
            _navigatorKey.currentState?.pushReplacementNamed('/login');
          }
        } catch (e) {
          // If there's an error, stay on current screen
          print('Error checking auth on resume: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (context) => const PinLoginPage(),
        '/home': (context) => const WalletScreen(),
      },
      theme: ThemeData(
        primaryColor: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.transparent,
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white),
          titleMedium: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white),
          bodyMedium: TextStyle(fontSize: 14, color: Colors.white70),
        ),
      ),
      home: const AppInitializer(),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      final isPinSetup = await AuthService.isPinSetup();
      
      if (!isPinSetup) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PinLoginPage()),
        );
        return;
      }
      
      final isAuthEnabled = await AuthService.isAuthEnabled();
      
      if (isAuthEnabled) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PinLoginPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WalletScreen()),
        );
      }
    } catch (e) {
      // If there's any error, default to login page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PinLoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF121212),
      body: Center(
        child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
      ),
    );
  }
}


