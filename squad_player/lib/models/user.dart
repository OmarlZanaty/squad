class User {
  final int id;
  final String name;
  final String email;
  final String type;

  final String? bio;
  final String? currentClub;
  final String? country;
  final String? position;

  final String? profilePhotoUrl;
  final String? coverPhotoUrl;

  final int? weight;
  final int? height;
  final int? age;

  final String? birthDate;
  final String? status;
  final String? createdAt;

  final int? followersCount;
  final int? followingCount;

  /// -1..1 (Alignment)
  final double coverFocusX;
  final double coverFocusY;
  final double profileFocusX;
  final double profileFocusY;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.type,
    this.bio,
    this.currentClub,
    this.country,
    this.position,
    this.profilePhotoUrl,
    this.coverPhotoUrl,
    this.weight,
    this.height,
    this.age,
    this.birthDate,
    this.status,
    this.createdAt,
    this.followersCount,
    this.followingCount,
    this.coverFocusX = 0,
    this.coverFocusY = 0,
    this.profileFocusX = 0,
    this.profileFocusY = 0,
  });

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double _toDouble(dynamic v, [double fallback = 0]) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  static double _focusFromJson(Map<String, dynamic> json, String snakeKey, String camelKey) {
    // ✅ Only read focus if backend actually sent it
    if (!json.containsKey(snakeKey) && !json.containsKey(camelKey)) return 0;
    final v = json[snakeKey] ?? json[camelKey];
    return _toDouble(v, 0).clamp(-1.0, 1.0);
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: _toInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      type: json['type']?.toString() ?? 'player',

      bio: json['bio']?.toString(),
      currentClub: json['current_club']?.toString(),
      country: json['country']?.toString(),
      position: json['position']?.toString(),

      profilePhotoUrl: json['profile_photo_url']?.toString(),
      coverPhotoUrl: json['cover_photo_url']?.toString(),

      weight: _toInt(json['weight']),
      height: _toInt(json['height']),
      age: _toInt(json['age']),

      birthDate: (json['birth_date'] ??
          json['birthDate'] ??
          json['birthday'] ??
          json['birthdate'])
          ?.toString(),
      status: json['status']?.toString(),
      createdAt: json['created_at']?.toString(),


      // backend you showed uses follower_count / following_count
      followersCount: _toInt(json['follower_count'] ?? json['followers_count']),
      followingCount: _toInt(json['following_count']),

      coverFocusX: _focusFromJson(json, 'cover_focus_x', 'coverFocusX'),
      coverFocusY: _focusFromJson(json, 'cover_focus_y', 'coverFocusY'),
      profileFocusX: _focusFromJson(json, 'profile_focus_x', 'profileFocusX'),
      profileFocusY: _focusFromJson(json, 'profile_focus_y', 'profileFocusY'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'type': type,
      'bio': bio,
      'current_club': currentClub,
      'country': country,
      'position': position,
      'profile_photo_url': profilePhotoUrl,
      'cover_photo_url': coverPhotoUrl,
      'weight': weight,
      'height': height,
      'age': age,
      'birth_date': birthDate,
      'status': status,
      'created_at': createdAt,

      // ✅ keep same as backend read (follower_count)
      'follower_count': followersCount,
      'following_count': followingCount,

      'cover_focus_x': coverFocusX,
      'cover_focus_y': coverFocusY,
      'profile_focus_x': profileFocusX,
      'profile_focus_y': profileFocusY,
    };
  }
}