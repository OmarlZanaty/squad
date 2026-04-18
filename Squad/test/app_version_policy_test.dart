import 'package:flutter_test/flutter_test.dart';
import 'package:squad/models/app_version_policy.dart';

void main() {
  group('AppVersionPolicy.fromJson', () {
    test('parses snake_case', () {
      final policy = AppVersionPolicy.fromJson({
        'latest_version': '1.2.0',
        'minimum_version': '1.1.0',
        'force_update': true,
        'maintenance_mode': false,
        'message': 'Update now',
      });

      expect(policy.latestVersion, '1.2.0');
      expect(policy.minimumVersion, '1.1.0');
      expect(policy.forceUpdate, isTrue);
      expect(policy.maintenanceMode, isFalse);
    });

    test('parses camelCase fallback', () {
      final policy = AppVersionPolicy.fromJson({
        'latestVersion': '2.0.0',
        'minimumVersion': '1.9.0',
        'forceUpdate': 1,
      });

      expect(policy.latestVersion, '2.0.0');
      expect(policy.minimumVersion, '1.9.0');
      expect(policy.forceUpdate, isTrue);
    });
  });
}
