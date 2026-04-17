import 'package:video_player/video_player.dart';

class VideoControllerPool {

  static const int maxPoolSize = 5;

  static final Map<String, VideoPlayerController> _controllers = {};


  static Future<VideoPlayerController> getController(String url) async {
    if (_controllers.containsKey(url)) {
      return _controllers[url]!;
    }

    // 🔥 LIMIT POOL SIZE
    if (_controllers.length >= maxPoolSize) {
      final oldestKey = _controllers.keys.first;

      _controllers[oldestKey]?.dispose();
      _controllers.remove(oldestKey);
    }

    final controller = VideoPlayerController.network(url);
    await controller.initialize();

    _controllers[url] = controller;

    return controller;
  }

  static void disposeUnused(Set<String> activeUrls) {
    final keys = _controllers.keys.toList();
    for (var key in keys) {
      if (!activeUrls.contains(key)) {
        try { _controllers[key]?.dispose(); } catch (_) {}
        _controllers.remove(key);
      }
    }
  }
}