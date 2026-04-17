import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:squad/utils/app_colors.dart';
import 'package:squad/services/api_service.dart';
import 'package:squad/services/auth_service.dart';
import 'package:squad/models/post.dart';
import 'package:squad/utils/app_localizations.dart';

class EditPostScreen extends StatefulWidget {
  final Post post;

  const EditPostScreen({super.key, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late TextEditingController _contentController;
  final _imagePicker = ImagePicker();
  File? _newMedia; // New media selected by user
  bool _removeExistingMedia = false; // Flag to remove existing media
  bool _isVideo = false;
  bool _isLoading = false;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.post.caption ?? '');
    _isVideo = widget.post.mediaType == 'video';
  }

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
          _newMedia = File(image.path);
          _isVideo = false;
          _removeExistingMedia = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc?.tr('error_picking_image') ??
                'Error picking image'}: $e'),
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
        maxDuration: const Duration(minutes: 5),
      );

      if (video != null) {
        _disposeVideoController();
        setState(() {
          _newMedia = File(video.path);
          _isVideo = true;
          _removeExistingMedia = false;
        });
        _initializeVideoPlayer();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc?.tr('error_picking_video') ??
                'Error picking video'}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _initializeVideoPlayer() {
    if (_newMedia != null && _isVideo) {
      _videoController = VideoPlayerController.file(_newMedia!)
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
    setState(() {
      _newMedia = null;
      _removeExistingMedia = true;
      _disposeVideoController();
    });
  }

  void _showMediaOptions() {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (context) =>
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: Text(loc?.tr('choose_photo') ?? 'Choose Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.video_library),
                  title: Text(loc?.tr('choose_video') ?? 'Choose Video'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickVideo();
                  },
                ),
                if (widget.post.mediaUrl.isNotEmpty || _newMedia != null)
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: Text(
                      loc?.tr('remove_media') ?? 'Remove Media',
                      style: const TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _removeMedia();
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.cancel),
                  title: Text(loc?.tr('cancel') ?? 'Cancel'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _updatePost() async {
    final loc = AppLocalizations.of(context);

    if (_contentController.text
        .trim()
        .isEmpty &&
        widget.post.mediaUrl.isEmpty &&
        _newMedia == null &&
        !_removeExistingMedia) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              loc?.tr('must_add_text_or_media') ?? 'Must add text or media'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final result = await ApiService.updatePost(
        token,
        widget.post.id,
        {
          'content': _contentController.text.trim(),
          if (_newMedia != null) 'mediaPath': _newMedia!.path,
          if (_removeExistingMedia) 'removeMedia': true,
        },
      );

      if (mounted) {
        if (result['message'] != null) {
          Navigator.pop(context, true); // Return true to indicate success
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc?.tr('post_updated_successfully') ??
                  'Post updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception(result['message'] ?? 'Failed to update post');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${loc?.tr('error_updating') ?? 'Error updating'}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
              // Header
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      loc?.tr('edit_post') ?? 'Edit Post',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the close button
                ],
              ),
              const SizedBox(height: 20),

              // Text field
              TextField(
                controller: _contentController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: loc?.tr('what_do_you_want_to_say') ??
                      'What do you want to say?',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Current or new media preview
              if (_newMedia != null) ...[
                // New media selected
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _isVideo
                          ? (_videoController != null &&
                          _videoController!.value.isInitialized
                          ? AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      )
                          : Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: const Center(child: CircularProgressIndicator()),
                      ))
                          : Image.file(
                        _newMedia!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: _removeMedia,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ] else
                if (!_removeExistingMedia &&
                    widget.post.mediaUrl.isNotEmpty) ...[
                  // Existing media (not removed)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: widget.post.mediaType == 'video'
                            ? Stack(
                          children: [
                            Container(
                              height: 200,
                              width: double.infinity,
                              color: Colors.black,
                              child: Image.network(
                                'http://187.124.37.68:3000${widget.post
                                    .mediaUrl}',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment
                                            .center,
                                        children: [
                                          const Icon(Icons.videocam, size: 64,
                                              color: Colors.grey),
                                          const SizedBox(height: 8),
                                          Text(
                                            loc?.tr('video') ?? 'Video',
                                            style: const TextStyle(
                                                color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Positioned.fill(
                              child: Center(
                                child: Icon(
                                  Icons.play_circle_outline,
                                  size: 64,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ),
                          ],
                        )
                            : Image.network(
                          'http://187.124.37.68:3000${widget.post.mediaUrl}',
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 200,
                              color: Colors.grey[300],
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                      null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            print('Image load error: $error');
                            return Container(
                              height: 200,
                              color: Colors.grey[300],
                              child: const Center(
                                child: Icon(Icons.broken_image, size: 50,
                                    color: Colors.grey),
                              ),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: _removeMedia,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

              // Change media button
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _showMediaOptions,
                icon: const Icon(Icons.photo_library),
                label: Text(
                  (_newMedia != null || (!_removeExistingMedia && widget.post
                      .mediaUrl.isNotEmpty))
                      ? (loc?.tr('change_media') ?? 'Change Media')
                      : (loc?.tr('add_photo_video') ?? 'Add Photo/Video'),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
        heroTag: 'post_fab',
        onPressed: _updatePost,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.save, color: Colors.white),
        label: Text(
          loc?.tr('save') ?? 'Save',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}