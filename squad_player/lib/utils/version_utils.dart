class VersionUtils {
  const VersionUtils._();

  /// Returns true when [current] is strictly older than [target].
  ///
  /// Examples:
  /// - `isOlderThan('1.2.0', '1.2.1') == true`
  /// - `isOlderThan('1.2.0', '1.2.0') == false`
  /// - `isOlderThan('1.3.0', '1.2.9') == false`
  static bool isOlderThan(String current, String target) {
    final currentParts = _parseSemverLike(current);
    final targetParts = _parseSemverLike(target);

    for (int i = 0; i < 3; i++) {
      if (currentParts[i] < targetParts[i]) return true;
      if (currentParts[i] > targetParts[i]) return false;
    }

    return false;
  }

  /// Parses a semver-like string into major/minor/patch integers.
  ///
  /// This parser is intentionally tolerant and extracts only numeric prefixes,
  /// so values like `1.2.3+45` or `1.2.3-beta.1` are treated as `1.2.3`.
  static List<int> _parseSemverLike(String value) {
    final rawParts = value.trim().split('.');
    return List<int>.generate(3, (index) {
      if (index >= rawParts.length) return 0;
      final match = RegExp(r'^\d+').firstMatch(rawParts[index]);
      return int.tryParse(match?.group(0) ?? '') ?? 0;
    });
  }
}
