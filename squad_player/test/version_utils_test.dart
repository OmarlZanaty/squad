import 'package:flutter_test/flutter_test.dart';
import 'package:squad_player/utils/version_utils.dart';

void main() {
  group('VersionUtils.isOlderThan', () {
    test('returns true when patch version is older', () {
      expect(VersionUtils.isOlderThan('1.2.0', '1.2.1'), isTrue);
    });

    test('returns false for equal versions', () {
      expect(VersionUtils.isOlderThan('1.2.0', '1.2.0'), isFalse);
    });

    test('returns false when current is newer', () {
      expect(VersionUtils.isOlderThan('1.3.0', '1.2.9'), isFalse);
    });

    test('handles semver suffixes safely', () {
      expect(VersionUtils.isOlderThan('1.2.3+45', '1.2.4-beta.1'), isTrue);
    });

    test('handles missing parts as zeros', () {
      expect(VersionUtils.isOlderThan('1.2', '1.2.1'), isTrue);
      expect(VersionUtils.isOlderThan('1', '1.0.0'), isFalse);
    });
  });
}
