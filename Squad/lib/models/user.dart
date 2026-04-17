class User {
  final int id;
  final String name;
  final String email;
  final String type;
  final String? phone;
  final String? bio;
  final String? country;
  final String? position;
  final String? profilePhotoUrl;
  final String? coverPhotoUrl;
  final int? weight;
  final int? height;
  final int? age;
  final String? birthDate;
  final String? currentClub;
  final String? status;
  final String? createdAt;
  final int? followersCount;
  final int? followingCount;
  final bool isVip;
  final int? viewsCount;

  // ✅ MUST be static to use inside factory
  static bool parseVip(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v == 1;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return false;
  }


  User({
    required this.id,
    required this.name,
    required this.email,
    required this.type,
    this.phone,
    this.bio,
    this.country,
    this.position,
    this.profilePhotoUrl,
    this.coverPhotoUrl,
    this.weight,
    this.height,
    this.age,
    this.birthDate,
    this.currentClub,
    this.status,
    this.createdAt,
    this.followersCount,
    this.followingCount,
    this.isVip = false, // ✅ default
    this.viewsCount,

  });



  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      type: json['type']?.toString() ?? 'player',
      phone: json['phone']?.toString(),
      bio: json['bio']?.toString(),
      country: json['country']?.toString(),
      position: json['position']?.toString(),
      profilePhotoUrl: json['profile_photo_url']?.toString(),
      coverPhotoUrl: json['cover_photo_url']?.toString(),
      weight: json['weight'] is int ? json['weight'] : (json['weight'] != null ? int.tryParse(json['weight'].toString()) : null),
      height: json['height'] is int ? json['height'] : (json['height'] != null ? int.tryParse(json['height'].toString()) : null),
      age: json['age'] is int ? json['age'] : (json['age'] != null ? int.tryParse(json['age'].toString()) : null),
      birthDate: json['birth_date']?.toString(),
      currentClub: json['current_club']?.toString(),
      status: json['status']?.toString(),
      createdAt: json['created_at']?.toString(),
      followersCount: json['follower_count'] is int ? json['follower_count'] : (json['follower_count'] != null ? int.tryParse(json['follower_count'].toString()) : null),
      followingCount: json['following_count'] is int ? json['following_count'] : (json['following_count'] != null ? int.tryParse(json['following_count'].toString()) : null),
      // ✅ VIP keys supported:
      isVip: parseVip(json['is_vip'] ?? json['isVip'] ?? json['vip']),
      viewsCount: json['views_count'] is int
          ? json['views_count']
          : (json['views_count'] != null ? int.tryParse(json['views_count'].toString()) : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'type': type,
      'phone': phone,
      'bio': bio,
      'country': country,
      'position': position,
      'profile_photo_url': profilePhotoUrl,
      'cover_photo_url': coverPhotoUrl,
      'weight': weight,
      'height': height,
      'age': age,
      'birth_date': birthDate,
      'current_club': currentClub,
      'status': status,
      'created_at': createdAt,
      'followers_count': followersCount,
      'following_count': followingCount,
    };
  }
}
