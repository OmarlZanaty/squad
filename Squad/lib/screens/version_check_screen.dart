import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:squad/config/app_config.dart';
import 'package:squad/models/app_version_policy.dart';
import 'package:squad/screens/force_update_screen.dart';
import 'package:squad/utils/version_utils.dart';

class VersionCheckScreen extends StatefulWidget {
  const VersionCheckScreen({super.key});

  @override
  State<VersionCheckScreen> createState() => _VersionCheckScreenState();
}

class _VersionCheckScreenState extends State<VersionCheckScreen> {
  bool _loading = true;
  String? _error;
  String _currentVersion = '-';
  String _packageName = '';
  AppVersionPolicy? _policy;
  String _status = 'Unknown';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final info = await PackageInfo.fromPlatform();
      final platform = Platform.isIOS ? 'ios' : 'android';
      final response = await http
          .get(Uri.parse('${AppConfig.appVersionPolicyUrl}?platform=$platform'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final policy =
          AppVersionPolicy.fromJson(jsonDecode(response.body) as Map<String, dynamic>);

      final current = info.version;
      String status;
      if (policy.maintenanceMode) {
        status = 'Maintenance mode';
      } else if (VersionUtils.isOlderThan(current, policy.minimumVersion)) {
        status = 'Blocked: update required';
      } else if (VersionUtils.isOlderThan(current, policy.latestVersion)) {
        status = 'Update available (optional)';
      } else {
        status = 'Up to date';
      }

      if (!mounted) return;
      setState(() {
        _currentVersion = current;
        _packageName = info.packageName;
        _policy = policy;
        _status = status;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openStore() async {
    final policy = _policy;
    if (policy == null) return;
    await ForceUpdateScreen.openStoreStatic(
      context,
      policy: policy,
      packageName: _packageName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final policy = _policy;
    return Scaffold(
      appBar: AppBar(title: const Text('Version check')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.verified),
                title: const Text('Status'),
                subtitle: Text(_status),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Current app version'),
                    subtitle: Text(_currentVersion),
                  ),
                  ListTile(
                    title: const Text('Latest version (backend)'),
                    subtitle: Text(policy?.latestVersion ?? '-'),
                  ),
                  ListTile(
                    title: const Text('Minimum version (backend)'),
                    subtitle: Text(policy?.minimumVersion ?? '-'),
                  ),
                  ListTile(
                    title: const Text('Force update flag (backend)'),
                    subtitle: Text('${policy?.forceUpdate ?? false}'),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Card(
                color: Colors.red.withOpacity(0.08),
                child: ListTile(
                  leading: const Icon(Icons.error_outline, color: Colors.red),
                  title: const Text('Could not load policy'),
                  subtitle: Text(_error!),
                ),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              label: Text(_loading ? 'Checking...' : 'Check again'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: policy == null ? null : _openStore,
              icon: const Icon(Icons.system_update_alt),
              label: const Text('Open store page'),
            ),
          ],
        ),
      ),
    );
  }
}
