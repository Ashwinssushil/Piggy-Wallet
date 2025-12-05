import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static Future<bool> isAuthEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('auth_enabled') ?? false;
  }
  
  static Future<void> setAuthEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auth_enabled', enabled);
  }
}