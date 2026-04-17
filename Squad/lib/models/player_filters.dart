class PlayerFilters {
  final String? position;
  final String? country;
  final String? ageRange;

  const PlayerFilters({this.position, this.country, this.ageRange});

  PlayerFilters copyWith({
    String? position,
    String? country,
    String? ageRange,
    bool clearPosition = false,
    bool clearCountry = false,
    bool clearAgeRange = false,
  }) {
    return PlayerFilters(
      position: clearPosition ? null : (position ?? this.position),
      country: clearCountry ? null : (country ?? this.country),
      ageRange: clearAgeRange ? null : (ageRange ?? this.ageRange),
    );
  }

  bool get isEmpty => position == null && country == null && ageRange == null;
}
