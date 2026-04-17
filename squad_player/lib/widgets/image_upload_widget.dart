import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_localizations.dart';

class ImageUploadWidget extends StatefulWidget {
  final Function(Map<String, dynamic> ) onImageUploaded;
  final bool allowMultiple;
  final String? apiBaseUrl;

  const ImageUploadWidget({
    Key? key,
    required this.onImageUploaded,
    this.allowMultiple = false,
    this.apiBaseUrl = 'http://localhost:3000',
  } ) : super(key: key);

  @override
  State<ImageUploadWidget> createState() => _ImageUploadWidgetState();
}

class _ImageUploadWidgetState extends State<ImageUploadWidget> {
  final ImagePicker _imagePicker = ImagePicker();
  List<XFile> _selectedImages = [];
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _uploadError;

  /// Get auth token from shared preferences
  Future<String> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      return token;
    } catch (e) {
      debugPrint('Error getting token: $e');
      return '';
    }
  }

  /// Pick image from gallery or camera
  Future<void> _pickImage({required ImageSource source}) async {
    final loc = AppLocalizations.of(context);
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          if (widget.allowMultiple) {
            _selectedImages.add(pickedFile);
          } else {
            _selectedImages = [pickedFile];
          }
          _uploadError = null;
        });
      }
    } catch (e) {
      _showError('${loc?.tr('failed_to_pick_image') ?? 'Failed to pick image'}: $e');
    }
  }

  /// Upload single image to backend
  Future<void> _uploadImage(XFile imageFile) async {
    final loc = AppLocalizations.of(context);
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadError = null;
    });

    try {
      final File file = File(imageFile.path);
      final int fileSize = await file.length();

      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${widget.apiBaseUrl}/api/media/upload-image' ),
      );

      // Add auth token
      final token = await _getToken();
      request.headers['Authorization'] = 'Bearer $token';

      // Add file
      request.files.add(
        http.MultipartFile(
          'image',
          file.openRead( ),
          fileSize,
          filename: imageFile.name,
        ),
      );

      // Send request with progress tracking
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        setState(() {
          _uploadProgress = 100.0;
        });

        // Call callback with uploaded image data
        widget.onImageUploaded(responseData);

        // Show success message
        _showSuccess(loc?.tr('image_uploaded_successfully') ?? 'Image uploaded successfully!');

        // Clear selected images
        setState(() {
          _selectedImages.clear();
        });
      } else {
        final errorData = jsonDecode(response.body);
        _showError(errorData['message'] ?? (loc?.tr('upload_failed') ?? 'Upload failed'));
      }
    } catch (e) {
      _showError('${loc?.tr('upload_error') ?? 'Upload error'}: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  /// Upload all selected images
  Future<void> _uploadAllImages() async {
    final loc = AppLocalizations.of(context);
    if (_selectedImages.isEmpty) {
      _showError(loc?.tr('please_select_image') ?? 'Please select at least one image');
      return;
    }

    for (int i = 0; i < _selectedImages.length; i++) {
      await _uploadImage(_selectedImages[i]);
      if (_uploadError != null) break;
    }
  }

  /// Remove selected image
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  /// Show error message
  void _showError(String message) {
    setState(() {
      _uploadError = message;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show success message
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc?.tr('upload_images') ?? 'Upload Images',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                loc?.tr('select_images_instruction') ?? 'Select images from your gallery or take a photo',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isUploading
                      ? null
                      : () => _pickImage(source: ImageSource.gallery),
                  icon: const Icon(Icons.image),
                  label: Text(loc?.tr('gallery') ?? 'Gallery'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isUploading
                      ? null
                      : () => _pickImage(source: ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: Text(loc?.tr('camera') ?? 'Camera'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        if (_selectedImages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${loc?.tr('selected_images') ?? 'Selected Images'} (${_selectedImages.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_selectedImages[index].path),
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        if (_isUploading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      loc?.tr('uploading') ?? 'Uploading...',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      '${_uploadProgress.toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _uploadProgress / 100,
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        if (_uploadError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _uploadError!,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 16),

        if (_selectedImages.isNotEmpty && !_isUploading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _uploadAllImages,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                ),
                child: Text(
                  loc?.tr('upload_images') ?? 'Upload Images',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

        const SizedBox(height: 16),
      ],
    );
  }
}
