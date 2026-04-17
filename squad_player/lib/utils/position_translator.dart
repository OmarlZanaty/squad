class PositionTranslator {
  static String toArabic(String? position) {
    if (position == null || position.isEmpty) return '';
    
    // Convert to uppercase for matching
    final pos = position.toUpperCase().trim();
    
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
}
