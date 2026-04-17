import 'dart:io';

class ShareLinks {
  // ✅ Android
  static const String squadPlayerAndroid =
      'https://play.google.com/store/apps/details?id=com.mohamed_helicopter.squad_player';
  static const String squadAndroid =
      'https://play.google.com/store/apps/details?id=com.mohamed_helicopter.squad';

  // ✅ iOS
  static const String squadIos =
      'https://apps.apple.com/eg/app/%D8%A5%D8%B3%D9%83%D9%88%D8%A7%D8%AF/id6756811679?l=ar';
  static const String squadPlayerIos =
      'https://apps.apple.com/eg/app/%D9%84%D8%A7%D8%B9%D8%A8-%D8%A5%D8%B3%D9%83%D9%88%D8%A7%D8%AF/id6756811939?l=ar';

  /// Which app is this build?
  /// - In squad_player app -> set isPlayerApp = true
  /// - In squad app -> set isPlayerApp = false
  static const bool isPlayerApp = false;

  static String profileText(int userId) {
    // Updated: use the landing page open-app handler with query parameters.
    // This avoids relying on server-side routing for /profile/:id, which may
    // be handled by a static host or CDN. The query parameters are parsed by
    // open-app.html to perform the deep link.
    return "https://squad-online.com/landing/open-app.html?type=profile&id=$userId";
  }

  static String postText(int postId) {
    return "https://squad-online.com/landing/open-app.html?type=post&id=$postId";
  }

  static String get storeLink {
    if (Platform.isIOS) {
      return isPlayerApp ? squadPlayerIos : squadIos;
    }
    // default Android + other platforms
    return isPlayerApp ? squadPlayerAndroid : squadAndroid;
  }

/// Optional: if you want to include post id info without using IP
/// This is NOT clickable to open inside app unless you implement deep links.
}