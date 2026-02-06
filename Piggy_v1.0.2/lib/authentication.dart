import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _pinKey = 'user_pin_hash';
  static const _isSetupKey = 'pin_setup_complete';
  static final LocalAuthentication _localAuth = LocalAuthentication();
  static bool _isAuthenticated = false;

  static Future<bool> isAuthEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('auth_enabled') ?? false;
  }
  
  static Future<void> setAuthEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auth_enabled', enabled);
  }

  static String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static Future<bool> isPinSetup() async {
    try {
      final setup = await _storage.read(key: _isSetupKey);
      return setup == 'true';
    } catch (e) {
      // Handle corrupted secure storage by clearing it
      await _clearCorruptedStorage();
      return false;
    }
  }

  static Future<void> setPin(String pin) async {
    if (pin.isEmpty) throw ArgumentError('PIN cannot be empty');
    
    try {
      final hashedPin = _hashPin(pin);
      await _storage.write(key: _pinKey, value: hashedPin);
      await _storage.write(key: _isSetupKey, value: 'true');
    } catch (e) {
      // Clear corrupted storage and retry
      await _clearCorruptedStorage();
      final hashedPin = _hashPin(pin);
      await _storage.write(key: _pinKey, value: hashedPin);
      await _storage.write(key: _isSetupKey, value: 'true');
    }
  }

  static Future<bool> validatePin(String pin) async {
    if (pin.isEmpty) return false;

    try {
      final storedHash = await _storage.read(key: _pinKey);
      if (storedHash == null) return false;

      final inputHash = _hashPin(pin);
      final isValid = storedHash == inputHash;

      if (isValid) {
        _isAuthenticated = true;
      }

      return isValid;
    } catch (e) {
      // Handle corrupted secure storage
      await _clearCorruptedStorage();
      return false;
    }
  }

  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_enabled') ?? false;
  }
  
  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', enabled);
  }

  static Future<bool> isBiometricAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> authenticateWithBiometrics() async {
    try {
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      if (!isAvailable) return false;

      final List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) return false;

      final bool isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Scan your fingerprint',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );

      if (isAuthenticated) {
        _isAuthenticated = true;
      }

      return isAuthenticated;
    } on PlatformException catch (e) {
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> _clearCorruptedStorage() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      // If deleteAll fails, try individual key deletion
      try {
        await _storage.delete(key: _pinKey);
        await _storage.delete(key: _isSetupKey);
      } catch (e) {
        // Last resort - ignore errors and continue
      }
    }
  }

  static bool isUserAuthenticated() {
    return _isAuthenticated;
  }

  static void clearAuthenticationState() {
    _isAuthenticated = false;
  }
}
