import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:squad/config/app_config.dart';
import 'package:squad/models/app_version_policy.dart';
import 'package:squad/screens/force_update_screen.dart';
import 'package:squad/services/auth_service.dart';
import 'package:squad/screens/login_screen.dart';
import 'package:squad/screens/main_screen.dart';
import 'package:squad/utils/version_utils.dart';

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

    _checkVersionAndNavigate();
  }

  Future<void> _checkVersionAndNavigate() async {
    await Future.delayed(const Duration(seconds: 3)); // Longer delay for slower animation

    if (!mounted) return;

    try {
      final info = await PackageInfo.fromPlatform();
      final platform = Platform.isIOS ? 'ios' : 'android';
      final res = await http
          .get(Uri.parse('${AppConfig.appVersionPolicyUrl}?platform=$platform'))
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200 && mounted) {
        final policy = AppVersionPolicy.fromJson(jsonDecode(res.body));
        final current = info.version;
        final packageName = info.packageName;

        if (policy.maintenanceMode && mounted) {
          _showMaintenanceDialog(policy.message);
          return;
        }

        if (VersionUtils.isOlderThan(current, policy.minimumVersion) && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ForceUpdateScreen(
                policy: policy,
                currentVersion: current,
                packageName: packageName,
              ),
            ),
          );
          return;
        }

        if (VersionUtils.isOlderThan(current, policy.latestVersion) && mounted) {
          final goUpdate = await _showSoftUpdateDialog(policy, current);
          if (!mounted) return;
          if (goUpdate == true) {
            await ForceUpdateScreen.openStoreStatic(
              context,
              policy: policy,
              packageName: packageName,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[Splash] Version check failed (non-blocking): $e');
    }

    // Check if user is already logged in
    final token = await AuthService.getToken();

    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      // User is logged in, go to home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } else {
      // User not logged in, go to login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Future<bool?> _showSoftUpdateDialog(AppVersionPolicy policy, String current) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.system_update, color: Colors.blue),
            SizedBox(width: 10),
            Text('تحديث جديد متاح', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(policy.message, style: const TextStyle(height: 1.5)),
            const SizedBox(height: 8),
            Text(
              'الإصدار الحالي: $current\nأحدث إصدار: ${policy.latestVersion}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('لاحقاً'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تحديث الآن'),
          ),
        ],
      ),
    );
  }

  void _showMaintenanceDialog(String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.build_circle, color: Colors.orange),
              SizedBox(width: 10),
              Text('صيانة مؤقتة'),
            ],
          ),
          content: Text(message, style: const TextStyle(height: 1.5)),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await Future.delayed(const Duration(seconds: 5));
                if (mounted) _checkVersionAndNavigate();
              },
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
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
