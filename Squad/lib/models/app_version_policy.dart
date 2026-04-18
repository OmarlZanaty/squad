class AppVersionPolicy {
  final String latestVersion;
  final String minimumVersion;
  final bool forceUpdate;
  final bool maintenanceMode;
  final String message;
  final String? androidStoreUrl;
  final String? iosStoreUrl;

  const AppVersionPolicy({
    required this.latestVersion,
    required this.minimumVersion,
    required this.forceUpdate,
    required this.maintenanceMode,
    required this.message,
    this.androidStoreUrl,
    this.iosStoreUrl,
  });

  factory AppVersionPolicy.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> storeUrls =
        json['store_urls'] is Map<String, dynamic>
            ? json['store_urls'] as Map<String, dynamic>
            : <String, dynamic>{};

    final latest =
        (json['latest_version'] ?? json['latestVersion'] ?? '').toString();
    final minimum =
        (json['minimum_version'] ?? json['minimumVersion'] ?? '').toString();

    return AppVersionPolicy(
      latestVersion: latest.isNotEmpty
          ? latest
          : (minimum.isNotEmpty ? minimum : '0.0.0'),
      minimumVersion: minimum.isNotEmpty
          ? minimum
          : (latest.isNotEmpty ? latest : '0.0.0'),
      forceUpdate: _asBool(json['force_update'] ?? json['forceUpdate']),
      maintenanceMode:
          _asBool(json['maintenance_mode'] ?? json['maintenanceMode']),
      message: (json['message'] ??
              'A new version of the app is required to continue.')
          .toString(),
      androidStoreUrl:
          (storeUrls['android'] ?? json['android_store_url'])?.toString(),
      iosStoreUrl: (storeUrls['ios'] ?? json['ios_store_url'])?.toString(),
    );
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    final text = value?.toString().toLowerCase().trim();
    return text == 'true' || text == '1';
  }
}
