import 'home.dart';
import 'authentication.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:simple_animations/simple_animations.dart';
import 'dart:math' as math;
import 'dart:ui';


class PinLoginPage extends StatefulWidget {
  const PinLoginPage({super.key});

  @override
  State<PinLoginPage> createState() => _PinLoginPageState();
}

class _PinLoginPageState extends State<PinLoginPage> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _showResult = false;
  bool _isSuccess = false;
  bool _isSetupMode = false;
  bool _isConfirming = false;
  String _firstPin = '';
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkPinSetup();
    _checkBiometricAvailability();
  }

  void _checkPinSetup() async {
    final isSetup = await AuthService.isPinSetup();
    if (mounted) {
      setState(() {
        _isSetupMode = !isSetup;
      });
    }
  }

  void _checkBiometricAvailability() async {
    final isAvailable = await AuthService.isBiometricAvailable();
    final isEnabled = await AuthService.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _biometricAvailable = isAvailable;
        _biometricEnabled = isEnabled;
      });
    }
  }

  void _authenticateWithBiometrics() async {
    HapticFeedback.lightImpact();

    final isAuthenticated = await AuthService.authenticateWithBiometrics();

    if (isAuthenticated) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WalletScreen()),
        );
      }
    } else {
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication failed. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2), // Half the default time (4s -> 2s)
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _handlePinSubmit() async {
    HapticFeedback.lightImpact();
    
    if (_isSetupMode) {
      if (!_isConfirming) {
        _firstPin = _pinController.text;
        if (mounted) {
          setState(() {
            _isConfirming = true;
          });
        }
        _pinController.clear();
      } else {
        if (_firstPin == _confirmPinController.text) {
          try {
            await AuthService.setPin(_firstPin);
            await AuthService.setAuthEnabled(true);
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const WalletScreen()),
              );
            }
          } catch (e) {
            HapticFeedback.heavyImpact();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to set PIN. Please try again.'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2), // Half the default time (4s -> 2s)
                ),
              );
              setState(() {
                _isConfirming = false;
                _firstPin = '';
              });
            }
            _confirmPinController.clear();
          }
        } else {
          HapticFeedback.heavyImpact();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('PINs do not match. Please try again.'),
                backgroundColor: Colors.deepPurple,
                duration: Duration(seconds: 2), // Half the default time (4s -> 2s)
              ),
            );
            setState(() {
              _isConfirming = false;
              _firstPin = '';
            });
          }
          _confirmPinController.clear();
        }
      }
    } else {
      final isValid = await AuthService.validatePin(_pinController.text);
      
      if (isValid) {
        HapticFeedback.heavyImpact();
        if (mounted) {
          setState(() {
            _showResult = true;
            _isSuccess = true;
          });
        }
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const WalletScreen()),
            );
          }
        });
      } else {
        HapticFeedback.heavyImpact();
        if (mounted) {
          setState(() {
            _showResult = true;
            _isSuccess = false;
          });
        }
        _pinController.clear();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _showResult = false;
            });
          }
        });
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.deepPurple.withOpacity(0.4),
                  Colors.purple.withOpacity(0.2),
                  const Color(0xFF121212),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          if (!_showResult) Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32.0, 120.0, 32.0, 32.0),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.deepPurple.withOpacity(0.4),
                              Colors.purple.withOpacity(0.2),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Icon(
                                _isSetupMode ? Icons.security : Icons.vpn_key,
                                size: 50,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                _isSetupMode 
                                  ? (_isConfirming ? 'Confirm Your PIN' : 'Set Your PIN')
                                  : 'Enter Your PIN',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (_isSetupMode) ...[
                                const SizedBox(height: 16),
                                Text(
                                  _isConfirming 
                                    ? 'Enter your PIN again to confirm'
                                    : 'Create a 4-digit PIN to secure your wallet',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 40),
                              Pinput(
                                controller: _isSetupMode && _isConfirming ? _confirmPinController : _pinController,
                                length: 4,
                                obscureText: true,
                                obscuringCharacter: '●',
                                onCompleted: (_) => _handlePinSubmit(),
                                validator: (value) => null,
                                defaultPinTheme: PinTheme(
                                  width: 64,
                                  height: 64,
                                  textStyle: const TextStyle(
                                      fontSize: 24,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.2),
                                        Colors.white.withValues(alpha: 0.1),
                                      ],
                                    ),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                ),
                                focusedPinTheme: PinTheme(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.deepPurpleAccent.withValues(alpha: 0.3),
                                        Colors.deepPurple.withValues(alpha: 0.2),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: Colors.deepPurpleAccent,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.deepPurpleAccent.withValues(alpha: 0.4),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                                errorPinTheme: PinTheme(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.redAccent),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              if (!_isSetupMode && _biometricAvailable && _biometricEnabled) ...[
                                const SizedBox(height: 30),
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.3),
                                      width: 1.5,
                                    ),
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.1),
                                        Colors.white.withValues(alpha: 0.05),
                                      ],
                                    ),
                                  ),
                                  child: OutlinedButton.icon(
                                    onPressed: _authenticateWithBiometrics,
                                    icon: const Icon(Icons.fingerprint, size: 24),
                                    label: const Text('Use Biometrics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      foregroundColor: Colors.white,
                                      side: BorderSide.none,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -130,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/piggy_icon.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showResult) ResultOverlay(isSuccess: _isSuccess),
        ],
      ),
    );
  }
}

class ResultOverlay extends StatelessWidget {
  final bool isSuccess;
  const ResultOverlay({super.key, required this.isSuccess});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PlayAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1200),
              builder: (context, value, child) {
                final bounceValue = value < 0.7 ? value / 0.7 : 1.0 + 0.3 * (1 - (value - 0.7) / 0.3);
                return Transform.scale(
                  scale: bounceValue,
                  child: Opacity(
                    opacity: value,
                    child: Icon(
                      isSuccess ? Icons.check_circle : Icons.cancel,
                      size: 120,
                      color: isSuccess ? Colors.green : Colors.red,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            PlayAnimationBuilder<double>(
              delay: const Duration(milliseconds: 600),
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Text(
                    isSuccess ? 'Login Successful!' : 'Login Failed!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isSuccess ? Colors.green : Colors.red,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class AnimatedBackground extends StatelessWidget {
  const AnimatedBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base gradient with morphing colors
        LoopAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(seconds: 8),
          builder: (context, value, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(const Color(0xFF000000), const Color(0xFF1A1A1A), value)!,
                    Color.lerp(const Color(0xFF0A0A0A), const Color(0xFF2A2A2A), value)!,
                    Color.lerp(const Color(0xFF1E1E1E), const Color(0xFF3A3A3A), value)!,
                  ],
                ),
              ),
            );
          },
        ),
        // Animated particles
        ...List.generate(15, (index) => AnimatedParticle(index: index)),
        // Mesh gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.3, -0.5),
              radius: 1.5,
              colors: [
                Colors.deepPurple.withValues(alpha: 0.1),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class AnimatedParticle extends StatelessWidget {
  final int index;
  const AnimatedParticle({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return LoopAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(seconds: 10 + (index % 5) * 2),
      builder: (context, value, child) {
        final x = (size.width * 0.1) + (size.width * 0.8 * ((value + index * 0.1) % 1));
        final y = (size.height * 0.1) + (size.height * 0.8 * math.sin(value * 2 * math.pi + index));
        return Positioned(
          left: x,
          top: y,
          child: Container(
            width: 3 + (index % 3),
            height: 3 + (index % 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1 + (index % 3) * 0.05),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurpleAccent.withValues(alpha: 0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}