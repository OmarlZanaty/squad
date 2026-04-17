import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_compress/video_compress.dart';

import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/upload_manager.dart';
import '../utils/app_colors.dart';
import '../utils/app_localizations.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});
  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _captionCtrl = TextEditingController();
  final _picker = ImagePicker();

  File? _selectedMedia;
  bool _isVideo = false;
  VideoPlayerController? _videoCtrl;

  String?      _taskId;
  UploadState? _uploadState;
  bool         _isCompressing = false;
  bool         _isSubmitting  = false; // guards against double-submit

  @override
  void dispose() {
    _captionCtrl.dispose();
    _videoCtrl?.dispose();
    // Cancel any in-progress compression to avoid the "bad state" error
    VideoCompress.cancelCompression();
    super.dispose();
  }

  // ── Media picking ─────────────────────────────────────────────────────────
  Future<void> _pick(ImageSource source, {required bool video}) async {
    // If a compression is running, cancel it first
    if (_isCompressing) {
      await VideoCompress.cancelCompression();
      if (mounted) setState(() => _isCompressing = false);
    }

    try {
      XFile? xfile;
      if (video) {
        xfile = await _picker.pickVideo(
          source: source,
          maxDuration: const Duration(minutes: 5),
        );
      } else {
        xfile = await _picker.pickImage(
          source: source,
          imageQuality: 85,
          maxWidth: 1920,
          maxHeight: 1080,
        );
      }
      if (xfile == null || !mounted) return;
      _videoCtrl?.dispose();
      _videoCtrl = null;
      setState(() {
        _selectedMedia = File(xfile!.path);
        _isVideo = video;
        _taskId = null;
        _uploadState = null;
      });
      if (video) await _initVideoPreview();
    } catch (e) {
      if (mounted) _snack('Error picking media: $e', Colors.red);
    }
  }

  Future<void> _initVideoPreview() async {
    if (_selectedMedia == null) return;
    final c = VideoPlayerController.file(_selectedMedia!);
    _videoCtrl = c;
    try {
      await c.initialize();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _removeMedia() {
    if (_isCompressing) VideoCompress.cancelCompression();
    _videoCtrl?.dispose();
    _videoCtrl = null;
    setState(() {
      _selectedMedia = null;
      _isVideo = false;
      _isCompressing = false;
      _taskId = null;
      _uploadState = null;
    });
  }

  void _showMediaSheet() {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: Text(loc?.tr('choose_photo') ?? 'Photo'),
            onTap: () { Navigator.pop(ctx); _pick(ImageSource.gallery, video: false); },
          ),
          ListTile(
            leading: const Icon(Icons.video_library),
            title: Text(loc?.tr('choose_video') ?? 'Video'),
            onTap: () { Navigator.pop(ctx); _pick(ImageSource.gallery, video: true); },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: Text(loc?.tr('take_photo') ?? 'Camera'),
            onTap: () { Navigator.pop(ctx); _pick(ImageSource.camera, video: false); },
          ),
          ListTile(
            leading: const Icon(Icons.videocam),
            title: Text(loc?.tr('record_video') ?? 'Record'),
            onTap: () { Navigator.pop(ctx); _pick(ImageSource.camera, video: true); },
          ),
        ]),
      ),
    );
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_isSubmitting) return; // prevent double-submit
    final loc = AppLocalizations.of(context);
    final caption = _captionCtrl.text.trim();

    if (caption.isEmpty && _selectedMedia == null) {
      _snack(loc?.tr('add_content_or_media') ?? 'Add content or media', Colors.orange);
      return;
    }

    final token = await AuthService.getToken();
    if (token == null) { _snack('Not authenticated', Colors.red); return; }

    setState(() => _isSubmitting = true);

    try {
      // ── TEXT-ONLY path (no file) ──────────────────────────────────────
      if (_selectedMedia == null) {
        final result = await ApiService.createPost(
          token: token,
          content: caption,
        );
        if (!mounted) return;
        if (result['success'] == true || result['id'] != null) {
          Navigator.pop(context, true);
        } else {
          _snack(result['message']?.toString() ?? 'Failed to post', Colors.red);
        }
        return;
      }

      // ── MEDIA path ────────────────────────────────────────────────────
      final sizeMB = await _selectedMedia!.length() / (1024 * 1024);
      if (sizeMB > 150) {
        _snack('حجم الملف كبير جداً (الحد الأقصى 150MB)', Colors.red);
        return;
      }

      File fileToUpload = _selectedMedia!;

      // Compress video — guard against double-compression
      if (_isVideo) {
        // ── FIX: cancel any existing compression before starting new one ──
        if (VideoCompress.isCompressing) {
          await VideoCompress.cancelCompression();
          await Future.delayed(const Duration(milliseconds: 300));
        }

        if (mounted) setState(() => _isCompressing = true);

        try {
          final quality = sizeMB > 80
              ? VideoQuality.LowQuality
              : sizeMB > 30
              ? VideoQuality.MediumQuality
              : VideoQuality.DefaultQuality;

          final info = await VideoCompress.compressVideo(
            _selectedMedia!.path,
            quality: quality,
            includeAudio: true,
            frameRate: 30,
          );
          if (info?.file != null) fileToUpload = info!.file!;
        } catch (compErr) {
          // ── FIX: If compression fails, use original file instead of crashing ──
          debugPrint('[CreatePost] Compression failed, using original: $compErr');
          fileToUpload = _selectedMedia!;
        } finally {
          if (mounted) setState(() => _isCompressing = false);
        }
      }

      // Enqueue chunked upload
      final taskId = await UploadManager.instance.enqueue(
        file: fileToUpload,
        caption: caption,
        token: token,
        isVideo: _isVideo,
      );

      if (!mounted) return;
      setState(() => _taskId = taskId);

      UploadManager.instance.taskStream(taskId).listen((state) {
        if (!mounted) return;
        setState(() => _uploadState = state);

        if (state.isDone) {
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) Navigator.pop(context, true);
          });
        } else if (state.isFailed) {
          if (mounted) setState(() => _isSubmitting = false);
          _snack('Upload failed: ${state.errorMessage}', Colors.red);
        }
      });

    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _snack('Error: $e', Colors.red);
      }
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.darkAccent : AppColors.primary;

    final isBusy = _uploadState?.isActive == true || _isCompressing || _isSubmitting;
    final progress = _uploadState?.progress ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc?.tr('create_post') ?? 'Create Post'),
        actions: [
          if (!isBusy)
            TextButton(
              onPressed: _submit,
              child: Text(
                loc?.tr('post') ?? 'Post',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _captionCtrl,
                maxLines: 5,
                enabled: !isBusy,
                decoration: InputDecoration(
                  hintText: loc?.tr('whats_on_your_mind') ?? "What's on your mind?",
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Media preview
              if (_selectedMedia != null) ...[
                Stack(children: [
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 300),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[900],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _isVideo
                          ? (_videoCtrl?.value.isInitialized == true
                          ? AspectRatio(
                        aspectRatio: _videoCtrl!.value.aspectRatio,
                        child: VideoPlayer(_videoCtrl!),
                      )
                          : const Center(child: CircularProgressIndicator()))
                          : Image.file(_selectedMedia!, fit: BoxFit.cover),
                    ),
                  ),
                  if (!isBusy)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: _removeMedia,
                        style: IconButton.styleFrom(backgroundColor: Colors.black54),
                      ),
                    ),
                  if (_isVideo && _videoCtrl?.value.isInitialized == true && !isBusy)
                    Positioned.fill(
                      child: Center(
                        child: IconButton(
                          icon: Icon(
                            _videoCtrl!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 56,
                            color: Colors.white,
                          ),
                          onPressed: () => setState(() {
                            _videoCtrl!.value.isPlaying
                                ? _videoCtrl!.pause()
                                : _videoCtrl!.play();
                          }),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 12),
              ],

              if (!isBusy)
                OutlinedButton.icon(
                  onPressed: _showMediaSheet,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: Text(loc?.tr('add_media') ?? 'Add Media'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),

              const SizedBox(height: 16),

              if (_isCompressing || _uploadState != null)
                _UploadProgressCard(
                  isCompressing: _isCompressing,
                  state: _uploadState,
                  accentColor: accent,
                ),

              const SizedBox(height: 16),

              if (!isBusy)
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: accent,
                  ),
                  child: Text(
                    loc?.tr('post') ?? 'Post',
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Progress card (unchanged from previous version) ─────────────────────────
class _UploadProgressCard extends StatelessWidget {
  final bool isCompressing;
  final UploadState? state;
  final Color accentColor;

  const _UploadProgressCard({
    required this.isCompressing,
    required this.state,
    required this.accentColor,
  });

  String get _label {
    if (isCompressing) return 'جاري ضغط الفيديو...';
    switch (state?.status) {
      case UploadStatus.uploading:  return 'جاري الرفع...';
      case UploadStatus.processing: return 'جاري المعالجة...';
      case UploadStatus.done:       return '✅ اكتمل!';
      case UploadStatus.failed:     return '❌ فشل الرفع';
      default:                      return 'جارٍ التحضير...';
    }
  }

  Color get _color {
    switch (state?.status) {
      case UploadStatus.done:   return Colors.green;
      case UploadStatus.failed: return Colors.red;
      default:                  return accentColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = state?.progress ?? 0.0;
    final indeterminate = isCompressing || state?.status == UploadStatus.processing;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(_statusIcon, color: _color, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(_label,
                style: TextStyle(fontWeight: FontWeight.w600, color: _color))),
            if (!indeterminate)
              Text('${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontWeight: FontWeight.bold, color: _color)),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: indeterminate ? null : progress,
              minHeight: 8,
              backgroundColor: Colors.grey.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(_color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            state?.status == UploadStatus.uploading
                ? 'يمكنك إغلاق الشاشة — الرفع يستمر في الخلفية'
                : isCompressing
                ? 'يتم ضغط الفيديو تلقائياً لتسريع الرفع...'
                : '',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          if (state?.isFailed == true && state?.errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(state!.errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  IconData get _statusIcon {
    if (isCompressing) return Icons.compress;
    switch (state?.status) {
      case UploadStatus.done:       return Icons.check_circle;
      case UploadStatus.failed:     return Icons.error;
      case UploadStatus.processing: return Icons.sync;
      default:                      return Icons.cloud_upload;
    }
  }
}