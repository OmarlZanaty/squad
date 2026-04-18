import 'package:flutter_test/flutter_test.dart';
import 'package:squad/utils/version_utils.dart';

void main() {
  group('VersionUtils.isOlderThan', () {
    test('returns true when current is older', () {
      expect(VersionUtils.isOlderThan('1.0.0', '1.0.1'), isTrue);
    });

    test('returns false when equal', () {
      expect(VersionUtils.isOlderThan('1.0.0', '1.0.0'), isFalse);
    });

    test('handles semver suffixes', () {
      expect(VersionUtils.isOlderThan('1.0.13+16', '1.0.14+17'), isTrue);
    });
  });
}
