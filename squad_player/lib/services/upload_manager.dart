import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../config/app_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Upload task state
// ─────────────────────────────────────────────────────────────────────────────
enum UploadStatus {
  queued,
  compressing,
  uploading,
  processing,  // server-side video processing
  done,
  failed,
}

class UploadState {
  final String taskId;
  final UploadStatus status;
  final double progress;      // 0.0–1.0 for uploading phase
  final String? errorMessage;
  final int? postId;          // set when done

  const UploadState({
    required this.taskId,
    required this.status,
    this.progress = 0,
    this.errorMessage,
    this.postId,
  });

  bool get isDone    => status == UploadStatus.done;
  bool get isFailed  => status == UploadStatus.failed;
  bool get isActive  => !isDone && !isFailed;

  UploadState copyWith({
    UploadStatus? status,
    double? progress,
    String? errorMessage,
    int? postId,
  }) => UploadState(
    taskId: taskId,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    errorMessage: errorMessage ?? this.errorMessage,
    postId: postId ?? this.postId,
  );

  @override
  String toString() =>
      'UploadState($taskId status=$status progress=${(progress * 100).toStringAsFixed(0)}% postId=$postId)';
}

// ─────────────────────────────────────────────────────────────────────────────
// UploadManager — singleton
// ─────────────────────────────────────────────────────────────────────────────
class UploadManager {
  UploadManager._();
  static final instance = UploadManager._();

  final Map<String, _UploadTask> _tasks = {};

  // Enqueue a new upload.  Returns a taskId you can use to observe progress.
  Future<String> enqueue({
    required File file,
    required String caption,
    required String token,
    required bool isVideo,
  }) async {
    final taskId = '${DateTime.now().millisecondsSinceEpoch}_${file.path.hashCode.abs()}';
    final task = _UploadTask(
      taskId: taskId,
      file: file,
      caption: caption,
      token: token,
      isVideo: isVideo,
    );
    _tasks[taskId] = task;
    task.start();
    debugPrint('[UploadManager] Enqueued task $taskId');
    return taskId;
  }

  // Stream of state updates for a given task
  Stream<UploadState> taskStream(String taskId) {
    final task = _tasks[taskId];
    if (task == null) return const Stream.empty();
    return task.stateStream;
  }

  UploadState? currentState(String taskId) => _tasks[taskId]?._state;

  void cancelAll() {
    for (final t in _tasks.values) t.cancel();
    _tasks.clear();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _UploadTask — internal worker
// ─────────────────────────────────────────────────────────────────────────────
class _UploadTask {
  static const int _chunkSize      = 2 * 1024 * 1024; // 2 MB
  static const int _maxChunkRetries= 5;
  static const int _pollIntervalMs = 3000;
  static const int _maxPollTries   = 30; // 90 s total

  final String taskId;
  final File   file;
  final String caption;
  final String token;
  final bool   isVideo;

  final _ctrl = StreamController<UploadState>.broadcast();
  Stream<UploadState> get stateStream => _ctrl.stream;

  bool _cancelled = false;

  UploadState _state = const UploadState(taskId: '', status: UploadStatus.queued);

  _UploadTask({
    required this.taskId,
    required this.file,
    required this.caption,
    required this.token,
    required this.isVideo,
  }) {
    _state = UploadState(taskId: taskId, status: UploadStatus.queued);
  }

  void _emit(UploadState s) {
    _state = s;
    if (!_ctrl.isClosed) _ctrl.add(s);
    debugPrint('[UploadTask][$taskId] $s');
  }

  void cancel() {
    _cancelled = true;
    if (!_ctrl.isClosed) _ctrl.close();
  }

  // ── Entry point ───────────────────────────────────────────────────────────
  Future<void> start() async {
    try {
      if (_cancelled) return;

      // ── Step 1: Init upload session on server ──────────────────────────
      _emit(_state.copyWith(status: UploadStatus.uploading, progress: 0));

      final totalBytes  = await file.length();
      final totalChunks = (totalBytes / _chunkSize).ceil();
      final filename    = p.basename(file.path);

      debugPrint('[UploadTask][$taskId] Init: $filename $totalBytes bytes $totalChunks chunks');

      final initRes = await _post('/posts/chunked/init', {
        'total_chunks': totalChunks,
        'total_size': totalBytes,
        'filename': filename,
        'caption': caption,
      });

      if (initRes == null) throw Exception('Init upload failed — no response from server');
      final uploadId = initRes['upload_id'] as String?;
      if (uploadId == null || uploadId.isEmpty) {
        throw Exception('Init upload failed — server returned no upload_id');
      }

      debugPrint('[UploadTask][$taskId] uploadId=$uploadId');

      // ── Step 2: Upload chunks ──────────────────────────────────────────
      final raf = await file.open();
      int uploadedBytes = 0;

      try {
        for (int i = 0; i < totalChunks; i++) {
          if (_cancelled) return;

          final offset = i * _chunkSize;
          final end    = (offset + _chunkSize > totalBytes) ? totalBytes : offset + _chunkSize;
          final length = end - offset;

          await raf.setPosition(offset);
          final chunkData = await raf.read(length);

          await _uploadChunkWithRetry(
            uploadId: uploadId,
            chunkIndex: i,
            totalChunks: totalChunks,
            chunkData: chunkData,
          );

          uploadedBytes += length;
          final progress = uploadedBytes / totalBytes;
          _emit(_state.copyWith(status: UploadStatus.uploading, progress: progress));
        }
      } finally {
        await raf.close();
      }

      // ── Step 3: Complete — server assembles + creates post row ─────────
      if (_cancelled) return;
      _emit(_state.copyWith(status: UploadStatus.processing, progress: 1.0));

      final completeRes = await _post('/posts/chunked/complete', {'upload_id': uploadId});
      if (completeRes == null) throw Exception('Complete failed — no response from server');

      final postId = completeRes['post']?['id'] as int?;
      debugPrint('[UploadTask][$taskId] Complete. postId=$postId');

      // ── Step 4: Poll until post is accessible (fixes race condition) ───
      if (postId != null) {
        await _pollUntilVisible(postId);
      }

      _emit(_state.copyWith(status: UploadStatus.done, progress: 1.0, postId: postId));
      if (!_ctrl.isClosed) _ctrl.close();

    } catch (e, st) {
      debugPrint('[UploadTask][$taskId] FAILED: $e\n$st');
      _emit(_state.copyWith(status: UploadStatus.failed, errorMessage: e.toString()));
      if (!_ctrl.isClosed) _ctrl.close();
    }
  }

  // ── Retry a single chunk ─────────────────────────────────────────────────
  Future<void> _uploadChunkWithRetry({
    required String uploadId,
    required int chunkIndex,
    required int totalChunks,
    required List<int> chunkData,
  }) async {
    int attempt = 0;
    while (true) {
      if (_cancelled) return;
      attempt++;
      try {
        final req = http.MultipartRequest(
          'POST',
          Uri.parse('${AppConfig.apiBaseUrl}/posts/chunked/upload'),
        );
        req.headers['Authorization'] = 'Bearer $token';
        req.fields['upload_id']    = uploadId;
        req.fields['chunk_index']  = chunkIndex.toString();
        req.fields['total_chunks'] = totalChunks.toString();
        req.files.add(http.MultipartFile.fromBytes(
          'chunk', chunkData,
          filename: 'chunk_$chunkIndex',
        ));

        final streamed = await req.send().timeout(const Duration(seconds: 60));
        final res = await http.Response.fromStream(streamed);

        if (res.statusCode == 200 || res.statusCode == 201) return; // ✅

        throw Exception('HTTP ${res.statusCode}: ${res.body}');

      } catch (e) {
        if (attempt >= _maxChunkRetries) {
          throw Exception('Chunk $chunkIndex failed after $attempt attempts: $e');
        }
        // Exponential back-off: 2s, 4s, 8s, 16s
        final waitMs = 2000 * (1 << (attempt - 1));
        debugPrint('[UploadTask][$taskId] Chunk $chunkIndex attempt $attempt failed, retrying in ${waitMs}ms: $e');
        await Future.delayed(Duration(milliseconds: waitMs));
      }
    }
  }

  // ── Poll GET /posts/:id until row is visible ─────────────────────────────
  Future<void> _pollUntilVisible(int postId) async {
    for (int i = 0; i < _maxPollTries; i++) {
      if (_cancelled) return;
      await Future.delayed(const Duration(milliseconds: _pollIntervalMs));
      try {
        final res = await http.get(
          Uri.parse('${AppConfig.apiBaseUrl}/posts/$postId'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          final data   = jsonDecode(res.body);
          final status = data['status'] as String? ?? '';
          if (status == 'active' || status == 'pending') {
            debugPrint('[UploadTask][$taskId] Post $postId visible with status=$status');
            return;
          }
          if (status == 'failed') {
            throw Exception('Server-side video processing failed for post $postId');
          }
        }
      } catch (pollErr) {
        debugPrint('[UploadTask][$taskId] Poll $i failed (non-fatal): $pollErr');
      }
    }
    // Timed out but post was created — not an error, just processing slowly
    debugPrint('[UploadTask][$taskId] Polling timed out — post created but still processing');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> _post(String path, Map<String, dynamic> body) async {
    int attempt = 0;
    while (attempt < 3) {
      attempt++;
      try {
        final res = await http.post(
          Uri.parse('${AppConfig.apiBaseUrl}$path'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 30));

        if (res.statusCode == 200 || res.statusCode == 201) {
          return jsonDecode(res.body) as Map<String, dynamic>;
        }
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      } catch (e) {
        if (attempt >= 3) rethrow;
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
    return null;
  }
}