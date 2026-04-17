class CareerEntry {
  final int? id;
  final int userId;
  final String clubName;
  final String years;
  final String? position;
  final String? achievements;
  final String? createdAt;

  CareerEntry({
    this.id,
    required this.userId,
    required this.clubName,
    required this.years,
    this.position,
    this.achievements,
    this.createdAt,
  });

  factory CareerEntry.fromJson(Map<String, dynamic> json) {
    return CareerEntry(
      id: json['id'],
      userId: json['user_id'],
      clubName: json['club_name'],
      years: json['years'],
      position: json['position'],
      achievements: json['achievements'],
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'club_name': clubName,
      'years': years,
      'position': position,
      'achievements': achievements,
      if (createdAt != null) 'created_at': createdAt,
    };
  }
}
