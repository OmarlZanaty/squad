import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class MediaCacheService {
  static final MediaCacheService _instance = MediaCacheService._internal();

  factory MediaCacheService() {
    return _instance;
  }

  MediaCacheService._internal();

  late Directory _cacheDir;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      _cacheDir = await getApplicationCacheDirectory();
      final mediaDir = Directory('${_cacheDir.path}/media');
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }
      _initialized = true;
    } catch (e) {
      print('Error initializing cache: $e');
    }
  }

  Future<File?> getCachedFile(String url, String fileName) async {
    await initialize();
    
    final file = File('${_cacheDir.path}/media/$fileName');
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  Future<File?> cacheFile(String url, String fileName) async {
    await initialize();
    
    try {
      final file = File('${_cacheDir.path}/media/$fileName');
      
      // Check if already cached
      if (await file.exists()) {
        return file;
      }

      // Download file
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        return file;
      }
    } catch (e) {
      print('Error caching file: $e');
    }
    return null;
  }

  Future<void> clearCache() async {
    await initialize();
    
    try {
      final mediaDir = Directory('${_cacheDir.path}/media');
      if (await mediaDir.exists()) {
        await mediaDir.delete(recursive: true);
        await mediaDir.create(recursive: true);
      }
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  Future<int> getCacheSize() async {
    await initialize();
    
    try {
      final mediaDir = Directory('${_cacheDir.path}/media');
      if (!await mediaDir.exists()) return 0;

      int size = 0;
      final files = mediaDir.listSync(recursive: true);
      for (var file in files) {
        if (file is File) {
          size += await file.length();
        }
      }
      return size;
    } catch (e) {
      print('Error getting cache size: $e');
      return 0;
    }
  }

  Future<List<File>> getCachedFiles() async {
    await initialize();
    
    try {
      final mediaDir = Directory('${_cacheDir.path}/media');
      if (!await mediaDir.exists()) return [];

      final files = <File>[];
      final entities = mediaDir.listSync(recursive: true);
      for (var entity in entities) {
        if (entity is File) {
          files.add(entity);
        }
      }
      return files;
    } catch (e) {
      print('Error getting cached files: $e');
      return [];
    }
  }

  String generateFileName(String url) {
    return url.hashCode.toString() + url.split('/').last;
  }

  bool isImageFile(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext);
  }

  bool isVideoFile(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return ['mp4', 'mkv', 'mov', 'avi', 'webm'].contains(ext);
  }
}
