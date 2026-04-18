import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Thrown when a chunk fails after all retries.
class ChunkUploadException implements Exception {
  final int chunkIndex;
  final String message;
  ChunkUploadException(this.chunkIndex, this.message);
  @override
  String toString() => 'ChunkUploadException(chunk=$chunkIndex): $message';
}

class ChunkedUploadService {
  static const int _defaultChunkSizeBytes = 2 * 1024 * 1024; // 2 MB
  static const int _maxRetries = 4;
  static const Duration _retryDelay = Duration(seconds: 3);

  static String get _baseUrl => AppConfig.apiBaseUrl;

  /// Upload [file] in chunks.
  ///
  /// [onProgress] receives (uploadedBytes, totalBytes).
  /// Returns the server response map from /posts/chunked/complete.
  static Future<Map<String, dynamic>> uploadChunked({
    required String token,
    required File file,
    required String caption,
    int chunkSize = _defaultChunkSizeBytes,
    void Function(int uploaded, int total)? onProgress,
  }) async {
    final totalBytes = await file.length();
    final totalChunks = (totalBytes / chunkSize).ceil();

    // ── 1. Initiate upload session ──────────────────────────────────────────
    final initRes = await http.post(
      Uri.parse('$_baseUrl/posts/chunked/init'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'total_chunks': totalChunks,
        'total_size': totalBytes,
        'filename': file.path.split('/').last,
        'caption': caption,
      }),
    );

    if (initRes.statusCode != 200 && initRes.statusCode != 201) {
      throw Exception('Failed to init chunked upload: ${initRes.body}');
    }

    final initData = jsonDecode(initRes.body) as Map<String, dynamic>;
    final uploadId = initData['upload_id'] as String;

    // ── 2. Upload each chunk ────────────────────────────────────────────────
    final raf = await file.open();
    int uploadedBytes = 0;

    try {
      for (int i = 0; i < totalChunks; i++) {
        final offset = i * chunkSize;
        final end = (offset + chunkSize > totalBytes) ? totalBytes : offset + chunkSize;
        final length = end - offset;

        await raf.setPosition(offset);
        final chunkData = await raf.read(length);

        await _uploadChunkWithRetry(
          token: token,
          uploadId: uploadId,
          chunkIndex: i,
          totalChunks: totalChunks,
          chunkData: chunkData,
        );

        uploadedBytes += length;
        onProgress?.call(uploadedBytes, totalBytes);
      }
    } finally {
      await raf.close();
    }

    // ── 3. Complete: server assembles file and creates Post atomically ───────
    final completeRes = await http.post(
      Uri.parse('$_baseUrl/posts/chunked/complete'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'upload_id': uploadId}),
    );

    if (completeRes.statusCode != 200 && completeRes.statusCode != 201) {
      throw Exception('Failed to complete upload: ${completeRes.body}');
    }

    final result = jsonDecode(completeRes.body) as Map<String, dynamic>;

    // ── 4. Poll until the post is visible (handles async video processing) ──
    final postId = result['post']?['id'] as int?;
    if (postId != null) {
      await _waitForPost(token: token, postId: postId);
    }

    return result;
  }

  // ── Retry wrapper for a single chunk ──────────────────────────────────────
  static Future<void> _uploadChunkWithRetry({
    required String token,
    required String uploadId,
    required int chunkIndex,
    required int totalChunks,
    required List<int> chunkData,
  }) async {
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        final req = http.MultipartRequest(
          'POST',
          Uri.parse('$_baseUrl/posts/chunked/upload'),
        );
        req.headers['Authorization'] = 'Bearer $token';
        req.fields['upload_id'] = uploadId;
        req.fields['chunk_index'] = chunkIndex.toString();
        req.fields['total_chunks'] = totalChunks.toString();
        req.files.add(http.MultipartFile.fromBytes('chunk', chunkData, filename: 'chunk_$chunkIndex'));

        final streamed = await req.send().timeout(const Duration(seconds: 60));
        final res = await http.Response.fromStream(streamed);

        if (res.statusCode == 200 || res.statusCode == 201) return; // ✅ success

        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      } catch (e) {
        if (attempt >= _maxRetries) {
          throw ChunkUploadException(chunkIndex, e.toString());
        }
        // Exponential back-off: 3s, 6s, 12s
        await Future.delayed(_retryDelay * attempt);
      }
    }
  }

  // ── Poll until the post exists in the feed (fixes race condition) ─────────
  static Future<void> _waitForPost({
    required String token,
    required int postId,
    int maxAttempts = 15,
    Duration interval = const Duration(seconds: 2),
  }) async {
    for (int i = 0; i < maxAttempts; i++) {
      try {
        final res = await http.get(
          Uri.parse('$_baseUrl/posts/$postId'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final status = data['status'] as String? ?? '';
          // Accept active or pending (video still processing is fine)
          if (status == 'active' || status == 'pending') return;
        }
      } catch (_) {}
      await Future.delayed(interval);
    }
    // Don't throw — the post was created, just not yet visible. Caller can
    // navigate away and the feed will refresh.
  }
}