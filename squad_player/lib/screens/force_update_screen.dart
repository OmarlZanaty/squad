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

  String _storeUrl() {
    if (Platform.isIOS) {
      return policy.iosStoreUrl ?? AppConfig.iosStoreUrl;
    }

    return policy.androidStoreUrl ??
        AppConfig.androidStoreUrlFromPackage(packageName);
  }

  Future<void> _openStore(BuildContext context) async {
    final uri = Uri.parse(_storeUrl());

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the store page.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
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
                    const Icon(
                      Icons.system_update,
                      color: Colors.white,
                      size: 72,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Update Required',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      policy.message,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Current version: $currentVersion\nMinimum required: ${policy.minimumVersion}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _openStore(context),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Update Now'),
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