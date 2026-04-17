import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:squad/utils/app_colors.dart';
import 'package:squad/services/api_service.dart';
import 'package:squad/services/auth_service.dart';
import 'package:squad/utils/app_localizations.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  final _imagePicker = ImagePicker();
  File? _selectedMedia;
  bool _isVideo = false;
  bool _isLoading = false;
  VideoPlayerController? _videoController;

  @override
  void dispose() {
    _contentController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final loc = AppLocalizations.of(context);
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        _disposeVideoController();
        setState(() {
          _selectedMedia = File(image.path);
          _isVideo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc?.tr('error_picking_image') ?? 'Error picking image'}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    final loc = AppLocalizations.of(context);
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5), // 5 minute limit
      );

      if (video != null) {
        _disposeVideoController();
        setState(() {
          _selectedMedia = File(video.path);
          _isVideo = true;
        });
        _initializeVideoPlayer();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc?.tr('error_picking_video') ?? 'Error picking video'}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    final loc = AppLocalizations.of(context);
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        _disposeVideoController();
        setState(() {
          _selectedMedia = File(image.path);
          _isVideo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc?.tr('error_taking_photo') ?? 'Error taking photo'}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _recordVideo() async {
    final loc = AppLocalizations.of(context);
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5),
      );

      if (video != null) {
        _disposeVideoController();
        setState(() {
          _selectedMedia = File(video.path);
          _isVideo = true;
        });
        _initializeVideoPlayer();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc?.tr('error_recording_video') ?? 'Error recording video'}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _initializeVideoPlayer() {
    if (_selectedMedia != null && _isVideo) {
      _videoController = VideoPlayerController.file(_selectedMedia!)
        ..initialize().then((_) {
          setState(() {});
        });
    }
  }

  void _disposeVideoController() {
    _videoController?.dispose();
    _videoController = null;
  }

  void _removeMedia() {
    _disposeVideoController();
    setState(() {
      _selectedMedia = null;
      _isVideo = false;
    });
  }

  void _showMediaOptions() {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(loc?.tr('choose_photo') ?? 'اختيار صورة'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: Text(loc?.tr('choose_video') ?? 'اختيار فيديو'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(loc?.tr('take_photo') ?? 'التقاط صورة'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: Text(loc?.tr('record_video') ?? 'تسجيل فيديو'),
              onTap: () {
                Navigator.pop(context);
                _recordVideo();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createPost() async {
    final loc = AppLocalizations.of(context);

    if (_contentController.text.trim().isEmpty && _selectedMedia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc?.tr('add_content_or_media') ?? 'Please add content or media'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      // Show uploading message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc?.tr('uploading') ?? 'Uploading...'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      final result = await ApiService.createPost(
        token: token,
        content: _contentController.text.trim(),
        mediaPath: _selectedMedia?.path,
      );

      if (mounted) {
        if (result['message'] != null) {
          Navigator.pop(context, true); // Return true to indicate success
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc?.tr('post_created_successfully') ?? 'Post created successfully'),
              backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkAccent : AppColors.primary,
            ),
          );
        } else {
          throw Exception(result['message'] ?? 'Failed to create post');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc?.tr('error') ?? 'Error'}: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _contentController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: loc?.tr('whats_on_your_mind') ?? "اكتب منشور",
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Media preview
              if (_selectedMedia != null) ...[
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 400),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[200],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _isVideo
                            ? (_videoController != null && _videoController!.value.isInitialized
                            ? AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        )
                            : const Center(child: CircularProgressIndicator()))
                            : Image.file(_selectedMedia!, fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: _removeMedia,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                        ),
                      ),
                    ),
                    if (_isVideo && _videoController != null && _videoController!.value.isInitialized)
                      Positioned.fill(
                        child: Center(
                          child: IconButton(
                            icon: Icon(
                              _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                              size: 64,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                if (_videoController!.value.isPlaying) {
                                  _videoController!.pause();
                                } else {
                                  _videoController!.play();
                                }
                              });
                            },
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              ElevatedButton.icon(
                onPressed: _showMediaOptions,
                icon: const Icon(Icons.add_photo_alternate),
                label: Text(loc?.tr('add_media') ?? 'إضافة وسائط'),
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: _isLoading ? null : _createPost,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkAccent : AppColors.primary,
                ),
                child: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : Text(
                  loc?.tr('post') ?? 'نشر',
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
