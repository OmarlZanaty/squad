import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squad_player/config/app_config.dart';
import 'package:squad_player/models/app_version_policy.dart';
import 'package:squad_player/screens/force_update_screen.dart';
import 'package:squad_player/screens/login_screen.dart';
import 'package:squad_player/screens/main_screen.dart';
import 'package:squad_player/services/auth_service.dart';

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

  // ── Main flow ─────────────────────────────────────────────────────────────
  Future<void> _checkVersionAndNavigate() async {
    // Wait for splash animation minimum duration
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    // ── Step 1: Version / maintenance check ──────────────────────────────
    try {
      final info     = await PackageInfo.fromPlatform();
      final platform = Platform.isIOS ? 'ios' : 'android';

      final res = await http
          .get(Uri.parse('${AppConfig.appVersionPolicyUrl}?platform=$platform'))
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200 && mounted) {
        final policy     = AppVersionPolicy.fromJson(jsonDecode(res.body));
        final current    = info.version;          // e.g. "1.2.0"
        final packageName= info.packageName;

        // Maintenance mode — block everything
        if (policy.maintenanceMode && mounted) {
          _showMaintenanceDialog(policy.message);
          return;
        }

        // Force update — go to ForceUpdateScreen (user cannot dismiss)
        if (policy.forceUpdate && _isOlderThan(current, policy.minimumVersion) && mounted) {
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
        if (_isOlderThan(current, policy.latestVersion) && mounted) {
          final goUpdate = await _showSoftUpdateDialog(policy, current);
          if (!mounted) return;
          if (goUpdate == true) {
            // Open store
            await ForceUpdateScreen.openStoreStatic(
              context,
              policy: policy,
              packageName: packageName,
            );
            // Still navigate into app after opening store
          }
        }
      }
    } catch (e) {
      // Network error during version check — don't block the user
      debugPrint('[Splash] Version check failed (non-blocking): $e');
    }

    if (!mounted) return;

    // ── Step 2: Auth check ────────────────────────────────────────────────
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

  // ── Version comparison helpers ────────────────────────────────────────────
  /// Returns true if [current] is strictly older than [required].
  bool _isOlderThan(String current, String required) {
    try {
      final c = _parse(current);
      final r = _parse(required);
      for (int i = 0; i < 3; i++) {
        if (c[i] < r[i]) return true;
        if (c[i] > r[i]) return false;
      }
      return false; // equal
    } catch (_) {
      return false;
    }
  }

  List<int> _parse(String v) {
    final parts = v.trim().split('.');
    return List.generate(3, (i) => i < parts.length ? int.tryParse(parts[i]) ?? 0 : 0);
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────
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
                // Allow retry after delay
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

  // ── Build ─────────────────────────────────────────────────────────────────
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
                      child: Image.asset('assets/images/SQlast.png', width: 250, height: 250),
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
/*

// ── Extension on ForceUpdateScreen to expose store opening statically ────────
extension ForceUpdateScreenExt on ForceUpdateScreen {
  void openStoreStatic(BuildContext context) {
    openStore(context);
  }
}*/
