class AppConfig {
  static const String apiBaseUrl = 'http://187.124.37.68:3000/api';

  // App update / version policy
  static const String appVersionPolicyPath = '/app/version-policy';
  static const String iosAppStoreId = '1234567890';

  static String get appVersionPolicyUrl => '$apiBaseUrl$appVersionPolicyPath';

  static String get iosStoreUrl => 'https://apps.apple.com/app/id$iosAppStoreId';

  static String androidStoreUrlFromPackage(String packageName) {
    return 'https://play.google.com/store/apps/details?id=$packageName';
  }
}
