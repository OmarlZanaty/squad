class VersionUtils {
  const VersionUtils._();

  /// Returns true when [current] is strictly older than [target].
  ///
  /// Handles semver suffixes like `1.2.3+45` or `1.2.3-beta.1`
  /// by ignoring everything after the first `+` or `-`.
  ///
  /// Examples:
  ///   isOlderThan('1.2.0', '1.2.1') == true
  ///   isOlderThan('1.2.0', '1.2.0') == false
  ///   isOlderThan('1.3.0', '1.2.9') == false
  ///   isOlderThan('1.2.3+45', '1.2.4-beta.1') == true
  static bool isOlderThan(String current, String target) {
    final c = _parse(current);
    final t = _parse(target);
    for (int i = 0; i < 3; i++) {
      if (c[i] < t[i]) return true;
      if (c[i] > t[i]) return false;
    }
    return false; // equal → not older
  }

  static List<int> _parse(String version) {
    // Strip build metadata (+45) and pre-release tags (-beta.1)
    final clean = version.trim().split(RegExp(r'[+\-]')).first;
    final parts = clean.split('.');
    return List.generate(3, (i) {
      if (i >= parts.length) return 0;
      return int.tryParse(RegExp(r'^\d+').firstMatch(parts[i])?.group(0) ?? '') ?? 0;
    });
  }
}