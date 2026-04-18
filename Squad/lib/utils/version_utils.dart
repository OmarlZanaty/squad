class VersionUtils {
  const VersionUtils._();

  static bool isOlderThan(String current, String target) {
    final currentParts = _parseSemverLike(current);
    final targetParts = _parseSemverLike(target);

    for (int i = 0; i < 3; i++) {
      if (currentParts[i] < targetParts[i]) return true;
      if (currentParts[i] > targetParts[i]) return false;
    }

    return false;
  }

  static List<int> _parseSemverLike(String value) {
    final rawParts = value.trim().split('.');
    return List<int>.generate(3, (index) {
      if (index >= rawParts.length) return 0;
      final match = RegExp(r'^\d+').firstMatch(rawParts[index]);
      return int.tryParse(match?.group(0) ?? '') ?? 0;
    });
  }
}
