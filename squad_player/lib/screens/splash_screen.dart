// lib/screens/splash_screen.dart
//
// KEY CHANGE: Sends ?platform=android&app_id=com.xxx.squad_player
// so the backend returns the policy for THIS app, not the Squad admin app.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:squad_player/config/app_config.dart';
import 'package:squad_player/models/app_version_policy.dart';
import 'package:squad_player/screens/force_update_screen.dart';
import 'package:squad_player/screens/login_screen.dart';
import 'package:squad_player/screens/main_screen.dart';
import 'package:squad_player/services/auth_service.dart';
import 'package:squad_player/utils/version_utils.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 3500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: -200.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -60.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -60.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -30.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -30.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 5,
      ),
    ]).animate(_controller);

    _controller.forward();
    _checkVersionAndNavigate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkVersionAndNavigate() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    try {
      final info        = await PackageInfo.fromPlatform();
      final current     = info.version;      // e.g. "1.0.13"
      final packageName = info.packageName;  // e.g. "com.mohamed_helicopter.squad_player"
      final platform    = Platform.isIOS ? 'ios' : 'android';

      // ✅ Send both platform AND app_id so backend returns the right row
      final url = Uri.parse(AppConfig.appVersionPolicyUrl)
          .replace(queryParameters: {
        'platform': platform,
        'app_id':   packageName,   // ← THIS is the key fix
      });

      debugPrint('[Splash] version=$current  package=$packageName');
      debugPrint('[Splash] Calling: $url');

      final res = await http.get(url).timeout(const Duration(seconds: 8));

      debugPrint('[Splash] HTTP ${res.statusCode}: ${res.body}');

      if (res.statusCode == 200 && mounted) {
        final policy = AppVersionPolicy.fromJson(jsonDecode(res.body));
        // Comes from pubspec.yaml `version: x.y.z+build`
        final current    = info.version;          // e.g. "1.2.0"
        final packageName= info.packageName;

        // Maintenance mode
        if (policy.maintenanceMode && mounted) {
          _showMaintenanceDialog(policy.message);
          return;
        }

        // Force update — go to ForceUpdateScreen (user cannot dismiss)
        if (VersionUtils.isOlderThan(current, policy.minimumVersion) &&
            mounted) {
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

        // Soft update — show dismissible banner then continue
        if (VersionUtils.isOlderThan(current, policy.latestVersion) &&
            mounted) {
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
    } catch (e, st) {
      debugPrint('[Splash] Version check error (non-blocking): $e\n$st');
    }

    if (!mounted) return;

    // Auth check
    final token = await AuthService.getToken();
    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────
  Future<bool?> _showSoftUpdateDialog(AppVersionPolicy policy, String current) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
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
          title: const Row(
            children: [
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(color: Color(0xFF252B3B)),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  Transform.translate(
                    offset: const Offset(0, -30),
                    child: Image.asset(
                      'assets/images/solgan2-removebg-preview.png',
                      width: 200,
                      height: 60,
                    ),
                  ),
                  const SizedBox(height: 20),
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