import 'package:flutter/material.dart';
import '../widgets/image_upload_widget.dart';

class UploadImageScreen extends StatefulWidget {
  const UploadImageScreen({Key? key}) : super(key: key);

  @override
  State<UploadImageScreen> createState() => _UploadImageScreenState();
}

class _UploadImageScreenState extends State<UploadImageScreen> {
  List<Map<String, dynamic>> _uploadedImages = [];

  void _handleImageUploaded(Map<String, dynamic> imageData) {
    setState(() {
      _uploadedImages.add(imageData);
    });

    // Show success dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload Successful'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Media ID: ${imageData['media_id']}'),
            const SizedBox(height: 8),
            Text('Size: ${imageData['metadata']['width']}x${imageData['metadata']['height']}'),
            const SizedBox(height: 8),
            Text('Compression: ${imageData['compression']['ratio']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Images'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ImageUploadWidget(
              onImageUploaded: _handleImageUploaded,
              allowMultiple: true,
            ),
            if (_uploadedImages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Uploaded Images (${_uploadedImages.length})',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _uploadedImages.length,
                      itemBuilder: (context, index) {
                        final image = _uploadedImages[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Image #${image['media_id']}',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text('Size: ${image['metadata']['width']}x${image['metadata']['height']}'),
                                Text('Format: ${image['metadata']['format']}'),
                                Text('Original: ${image['compression']['originalSize']}'),
                                Text('Compressed: ${image['compression']['compressedSize']}'),
                                Text('Saved: ${image['compression']['ratio']}'),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
