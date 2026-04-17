import 'dart:io';

class ShareLinks {

  // Android store
  static const String androidStore =
      'https://play.google.com/store/apps/details?id=com.mohamed_helicopter.squad_player';

  // iOS store
  static const String iosStore =
      'https://apps.apple.com/eg/app/لاعب-إسكواد/id6756811939';

  /// landing link that redirects to deep link
  static String postLink(int postId) {
    return "https://squad-online.com/landing/open-app.html?type=post&id=$postId";
  }

  static String profileLink(int userId) {
    return "https://squad-online.com/landing/open-app.html?type=profile&id=$userId";
  }

  static String get storeLink {
    if (Platform.isIOS) {
      return iosStore;
    }
    return androidStore;
  }
}