import 'package:flutter/material.dart';
import 'package:squad/utils/app_colors.dart';
import 'package:squad/services/auth_service.dart';
import 'package:squad/screens/login_screen.dart';
import 'package:squad/screens/main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 3500), // Much slower: 3.5 seconds
      vsync: this,
    );

    // Fade in gradually
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    // Realistic drop and double bounce animation
    // Starts at -600 (top), drops to 0 (touches text), bounces up twice with decreasing height
    _slideAnimation = TweenSequence<double>([
      // Phase 1: Drop down with gravity acceleration (50% of time)
      TweenSequenceItem(
        tween: Tween<double>(begin: -600.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInCubic)), // Gravity effect
        weight: 50,
      ),
      // Phase 2: First bounce up (larger bounce - 40px up) (15% of time)
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -40.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      // Phase 3: Fall back down from first bounce (10% of time)
      TweenSequenceItem(
        tween: Tween<double>(begin: -40.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 10,
      ),
      // Phase 4: Second bounce up (smaller bounce - 20px up) (10% of time)
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -20.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      // Phase 5: Final settle to rest position (5% of time)
      TweenSequenceItem(
        tween: Tween<double>(begin: -20.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 5,
      ),
    ]).animate(_controller);

    _controller.forward();

    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(seconds: 3)); // Longer delay for slower animation

    if (!mounted) return;

    // Check if user is already logged in
    final token = await AuthService.getToken();
    print('Splash: Token = $token'); // Debug

    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      // User is logged in, go to home
      print('Splash: Navigating to Home'); // Debug
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } else {
      // User not logged in, go to login
      print('Splash: Navigating to Login'); // Debug
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF252B3B),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo with slide animation
                  Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Image.asset(
                        'assets/images/SQlast.png',
                        width: 250,
                        height: 250,
                      ),
                    ),
                  ),


                  // Slogan - moved up with Transform to be very close to logo
                  Transform.translate(
                    offset: const Offset(0, -50), // Move slogan up by 50 pixels
                    child: Image.asset(
                      'assets/images/Solgan.png',
                      width: 200,
                      height: 60,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Loading Indicator
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
