import 'package:flutter_test/flutter_test.dart';
import 'package:squad_player/models/app_version_policy.dart';

void main() {
  group('AppVersionPolicy.fromJson', () {
    test('parses snake_case payload', () {
      final policy = AppVersionPolicy.fromJson({
        'latest_version': '1.5.0',
        'minimum_version': '1.3.0',
        'force_update': true,
        'maintenance_mode': false,
        'message': 'Please update',
        'store_urls': {
          'android': 'https://play.google.com/store/apps/details?id=my.app',
          'ios': 'https://apps.apple.com/app/id1234567890',
        },
      });

      expect(policy.latestVersion, '1.5.0');
      expect(policy.minimumVersion, '1.3.0');
      expect(policy.forceUpdate, isTrue);
      expect(policy.maintenanceMode, isFalse);
      expect(policy.androidStoreUrl, contains('play.google.com'));
      expect(policy.iosStoreUrl, contains('apps.apple.com'));
    });

    test('supports camelCase fallback and defaults', () {
      final policy = AppVersionPolicy.fromJson({
        'latestVersion': '2.0.0',
        'forceUpdate': 1,
      });

      expect(policy.latestVersion, '2.0.0');
      expect(policy.minimumVersion, '2.0.0');
      expect(policy.forceUpdate, isTrue);
      expect(policy.maintenanceMode, isFalse);
      expect(policy.message, isNotEmpty);
    });
  });
}
