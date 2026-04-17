class AppConfig {
  static const String apiBaseUrl = 'http://187.124.37.68:3000/api';
  static const String apiHost = 'http://187.124.37.68:3000';
  static const String s3BaseUrl = 'https://squad-player-storage.s3.me-central-1.amazonaws.com';


  // -------------------------------
  // App update / version policy
  // -------------------------------
  static const String appVersionPolicyPath = '/app/version-policy';

  // Change this to your real iOS App Store ID
  static const String iosAppStoreId = '1234567890';

  static String get appVersionPolicyUrl => '$apiBaseUrl$appVersionPolicyPath';

  static String get iosStoreUrl => 'https://apps.apple.com/app/id$iosAppStoreId';

  static String androidStoreUrlFromPackage(String packageName) {
    return 'https://play.google.com/store/apps/details?id=$packageName';
  }


  static String getMediaUrl(String? mediaUrl ) {
    if (mediaUrl == null || mediaUrl.isEmpty) {
      return '';
    }

    // Debug: Print what we received
    print('AppConfig.getMediaUrl() received: "$mediaUrl"');
    print('Starts with https://? ${mediaUrl.startsWith('https://' )}');
    print('Starts with http://? ${mediaUrl.startsWith('http://' )}');

    // If it's already a full URL (starts with http/https ), return as-is
    if (mediaUrl.startsWith('http://' ) || mediaUrl.startsWith('https://' )) {
      print('AppConfig.getMediaUrl() returning as-is: "$mediaUrl"');
      return mediaUrl;
    }

    // If it's a relative path, prepend the API host
    final result = '$apiHost$mediaUrl';
    print('AppConfig.getMediaUrl() prepending host, returning: "$result"');
    return result;
  }

  static String getPhotoUrl(String? photoUrl) {
    print('AppConfig.getPhotoUrl() called with: "$photoUrl"');
    return getMediaUrl(photoUrl);
  }

  static String getS3MediaUrl(String? mediaPath) {
    if (mediaPath == null || mediaPath.isEmpty) {
      return '';
    }
    if (mediaPath.startsWith('http://' ) || mediaPath.startsWith('https://' )) {
      return mediaPath;
    }
    return '$s3BaseUrl/$mediaPath';
  }
}
