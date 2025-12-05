import 'package:flutter/material.dart';
import 'login.dart';
import 'home.dart';
import 'auth_service.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
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
    if (state == AppLifecycleState.resumed) {
      final isAuthEnabled = await AuthService.isAuthEnabled();
      final isPinSetup = await PinService.isPinSetup();
      
      if (isAuthEnabled && isPinSetup) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const PinLoginPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
    final isPinSetup = await PinService.isPinSetup();
    
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


