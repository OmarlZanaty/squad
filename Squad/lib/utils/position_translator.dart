class PositionTranslator {
  static String toArabic(String? position) {
    if (position == null || position.isEmpty) return '';

    // Convert to uppercase for matching
    final pos = position.toUpperCase().trim();

    final p = pos.toLowerCase().trim();

// normalize common English variants into your translation keys
    const enMap = {
      'goalkeeper': 'goalkeeper',
      'gk': 'goalkeeper',

      'right back': 'right_back',
      'rb': 'right_back',
      'left back': 'left_back',
      'lb': 'left_back',
      'center back': 'center_back',
      'centre back': 'center_back',
      'cb': 'center_back',

      'defensive midfielder': 'defensive_midfielder',
      'cdm': 'defensive_midfielder',
      'central midfielder': 'central_midfielder',
      'cm': 'central_midfielder',
      'attacking midfielder': 'attacking_midfielder',
      'cam': 'attacking_midfielder',

      'right winger': 'right_winger',
      'rw': 'right_winger',
      'left winger': 'left_winger',
      'lw': 'left_winger',

      // IMPORTANT: your app must decide what LM/RM mean
      // If you want them treated as wingers:
      'left midfielder': 'left_winger',
      'lm': 'left_winger',
      'right midfielder': 'right_winger',
      'rm': 'right_winger',

      'striker': 'striker',
      'st': 'striker',
      'forward': 'forward',
      'cf': 'striker',
      'center forward': 'striker',
      'centre forward': 'striker',
      'second striker': 'striker',
      'ss': 'striker',
    };

    if (enMap.containsKey(p)) return enMap[p]!;
    // Football positions in Arabic
    final Map<String, String> positions = {
      // Goalkeeper
      'GK': 'حارس مرمى',
      'GOALKEEPER': 'حارس مرمى',

      // Defenders
      'CB': 'قلب دفاع',
      'CENTER BACK': 'قلب دفاع',
      'CENTRE BACK': 'قلب دفاع',
      'LB': 'ظهير أيسر',
      'LEFT BACK': 'ظهير أيسر',
      'RB': 'ظهير أيمن',
      'RIGHT BACK': 'ظهير أيمن',
      'LWB': 'ظهير جناح أيسر',
      'LEFT WING BACK': 'ظهير جناح أيسر',
      'RWB': 'ظهير جناح أيمن',
      'RIGHT WING BACK': 'ظهير جناح أيمن',
      'SW': 'كناس',
      'SWEEPER': 'كناس',

      // Midfielders
      'CDM': 'وسط دفاعي',
      'DEFENSIVE MIDFIELDER': 'وسط دفاعي',
      'CM': 'وسط ميدان',
      'CENTRAL MIDFIELDER': 'وسط ميدان',
      'MIDFIELDER': 'وسط ميدان',
      'CAM': 'وسط هجومي',
      'ATTACKING MIDFIELDER': 'وسط هجومي',
      'LM': 'وسط أيسر',
      'LEFT MIDFIELDER': 'وسط أيسر',
      'RM': 'وسط أيمن',
      'RIGHT MIDFIELDER': 'وسط أيمن',

      // Forwards/Wingers
      'LW': 'جناح أيسر',
      'LEFT WINGER': 'جناح أيسر',
      'LEFT WING': 'جناح أيسر',
      'WINGER': 'جناح',
      'RW': 'جناح أيمن',
      'RIGHT WINGER': 'جناح أيمن',
      'RIGHT WING': 'جناح أيمن',
      'ST': 'مهاجم',
      'STRIKER': 'مهاجم',
      'CF': 'مهاجم صريح',
      'CENTER FORWARD': 'مهاجم صريح',
      'CENTRE FORWARD': 'مهاجم صريح',
      'FORWARD': 'مهاجم',
      'SS': 'مهاجم ثاني',
      'SECOND STRIKER': 'مهاجم ثاني',
    };

    // Try exact match first
    if (positions.containsKey(pos)) {
      return positions[pos]!;
    }

    // Try partial match
    for (var entry in positions.entries) {
      if (pos.contains(entry.key) || entry.key.contains(pos)) {
        return entry.value;
      }
    }

    // Return original if no match found
    return position;
  }

  // NEW: Convert Arabic position to English translation key
  static String toTranslationKey(String? position) {
    if (position == null || position.isEmpty) return 'midfielder';

    final pos = position.trim();

    // Map Arabic positions to English translation keys
    final Map<String, String> arabicToKey = {
      'حارس مرمى': 'goalkeeper',
      'قلب دفاع': 'center_back',
      'ظهير أيسر': 'left_back',
      'ظهير أيمن': 'right_back',
      'ظهير جناح أيسر': 'left_back',
      'ظهير جناح أيمن': 'right_back',
      'كناس': 'center_back',
      'وسط دفاعي': 'defensive_midfielder',
      'وسط ميدان': 'central_midfielder',
      'وسط هجومي': 'attacking_midfielder',
      'وسط أيسر': 'left_winger',
      'وسط أيمن': 'right_winger',
      'جناح أيسر': 'left_winger',
      'جناح أيمن': 'right_winger',
      'جناح': 'winger',
      'مهاجم': 'striker',
      'مهاجم صريح': 'striker',
      'مهاجم ثاني': 'striker',
    };

    // Check if it's already an English position
    final posLower = pos.toLowerCase().replaceAll(' ', '_');
    if (posLower == 'goalkeeper' ||
        posLower == 'defender' ||
        posLower == 'midfielder' ||
        posLower == 'forward' ||
        posLower == 'striker' ||
        posLower.contains('back') ||
        posLower.contains('winger') ||
        posLower.contains('midfielder')) {
      return posLower;
    }

    // Try exact Arabic match
    if (arabicToKey.containsKey(pos)) {
      return arabicToKey[pos]!;
    }

    // Try partial Arabic match
    for (var entry in arabicToKey.entries) {
      if (pos.contains(entry.key) || entry.key.contains(pos)) {
        return entry.value;
      }
    }

    // Default fallback
    return 'midfielder';
  }
}
