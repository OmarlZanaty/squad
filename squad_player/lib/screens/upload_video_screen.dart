import 'package:flutter/material.dart';
import '../widgets/video_player_widget.dart';

class UploadVideoScreen extends StatefulWidget {
  const UploadVideoScreen({Key? key}) : super(key: key);

  @override
  State<UploadVideoScreen> createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends State<UploadVideoScreen> {
  List<Map<String, dynamic>> _uploadedVideos = [];

  void _handleVideoUploaded(Map<String, dynamic> videoData) {
    setState(() {
      _uploadedVideos.add(videoData);
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
            Text('Media ID: ${videoData['media_id']}'),
            const SizedBox(height: 8),
            Text('Duration: ${videoData['metadata']['originalDuration']}s'),
            const SizedBox(height: 8),
            Text('Resolution: ${videoData['metadata']['originalResolution']}'),
            const SizedBox(height: 8),
            Text('Compression: ${videoData['compression']['ratio']}'),
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
        title: const Text('Upload Videos'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Video Upload',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Select a video to upload from your device.'),
                ],
              ),
            ),
            if (_uploadedVideos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Uploaded Videos (${_uploadedVideos.length})',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _uploadedVideos.length,
                      itemBuilder: (context, index) {
                        final video = _uploadedVideos[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Video #${video['media_id']}',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text('Duration: ${video['metadata']['originalDuration']}s'),
                                Text('Resolution: ${video['metadata']['originalResolution']}'),
                                Text('Codec: ${video['metadata']['originalCodec']}'),
                                Text('Original: ${video['compression']['originalSize']}'),
                                Text('Compressed: ${video['compression']['compressedSize']}'),
                                Text('Saved: ${video['compression']['ratio']}'),
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
