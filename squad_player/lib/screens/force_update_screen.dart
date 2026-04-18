// lib/screens/force_update_screen.dart
//
// Adds the missing static openStoreStatic() method that splash_screen.dart calls.
// Everything else is identical to your existing file.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:squad_player/config/app_config.dart';
import 'package:squad_player/models/app_version_policy.dart';
import 'package:url_launcher/url_launcher.dart';

class ForceUpdateScreen extends StatelessWidget {
  final AppVersionPolicy policy;
  final String currentVersion;
  final String packageName;

  const ForceUpdateScreen({
    super.key,
    required this.policy,
    required this.currentVersion,
    required this.packageName,
  });

  // ── Instance store URL helper ─────────────────────────────────────────────
  String _storeUrl() {
    if (Platform.isIOS) {
      return policy.iosStoreUrl ?? AppConfig.iosStoreUrl;
    }
    return policy.androidStoreUrl ?? AppConfig.androidStoreUrlFromPackage(packageName);
  }

  Future<void> _openStore(BuildContext context) async {
    final uri = Uri.parse(_storeUrl());
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the store page.')),
      );
    }
  }

  // ── STATIC method called by SplashScreen for soft-update flow ────────────
  // splash_screen.dart calls:
  //   await ForceUpdateScreen.openStoreStatic(context, policy: p, packageName: pkg);
  static Future<void> openStoreStatic(
      BuildContext context, {
        required AppVersionPolicy policy,
        required String packageName,
      }) async {
    final String url;
    if (Platform.isIOS) {
      url = policy.iosStoreUrl ?? AppConfig.iosStoreUrl;
    } else {
      url = policy.androidStoreUrl ?? AppConfig.androidStoreUrlFromPackage(packageName);
    }

    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the store page.')),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // user cannot dismiss
      child: Scaffold(
        backgroundColor: const Color(0xFF252B3B),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Update icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.system_update_rounded,
                        color: Colors.white,
                        size: 52,
                      ),
                    ),
                    const SizedBox(height: 28),

                    const Text(
                      'تحديث مطلوب',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Update Required',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        policy.message,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'الإصدار الحالي: $currentVersion\nالإصدار المطلوب: ${policy.minimumVersion}',
                      style: const TextStyle(color: Colors.white38, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _openStore(context),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.download_rounded, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'تحديث الآن  /  Update Now',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}