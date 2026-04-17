class HomeAd {
  final int slot;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? finalImageUrl;
  final String? linkUrl;

  HomeAd({
    required this.slot,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.finalImageUrl,
    this.linkUrl,
  });

  factory HomeAd.fromJson(Map<String, dynamic> j) {
    String? pick(String a, String b) => (j[a] ?? j[b]) as String?;

    return HomeAd(
      slot: (j['slot'] ?? 0) is int ? (j['slot'] ?? 0) : int.tryParse('${j['slot']}') ?? 0,
      title: (j['title'] ?? '') as String,
      subtitle: j['subtitle'] as String?,
      imageUrl: pick('imageUrl', 'image_url'),
      finalImageUrl: pick('finalImageUrl', 'final_image_url'),
      linkUrl: pick('linkUrl', 'link'), // backend uses "link"
    );
  }
}