import 'package:flutter/material.dart';
import 'dart:io';

class CompressionPreviewWidget extends StatelessWidget {
  final File? selectedFile;
  final bool isVideo;
  final Map<String, dynamic>? compressionData;

  const CompressionPreviewWidget({
    Key? key,
    this.selectedFile,
    this.isVideo = false,
    this.compressionData,
  }) : super(key: key);

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  double _calculateCompressionRatio(int original, int compressed) {
    if (original == 0) return 0;
    return ((original - compressed) / original * 100);
  }

  @override
  Widget build(BuildContext context) {
    if (selectedFile == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text('No file selected'),
        ),
      );
    }

    final fileSize = selectedFile!.lengthSync();
    final fileName = selectedFile!.path.split('/').last;

    // Estimate compression (actual compression happens on backend)
    int estimatedCompressed = fileSize;
    if (isVideo) {
      // Videos typically compress 60-70%
      estimatedCompressed = (fileSize * 0.35).toInt();
    } else {
      // Images typically compress 80-90%
      estimatedCompressed = (fileSize * 0.15).toInt();
    }

    final ratio = _calculateCompressionRatio(fileSize, estimatedCompressed);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue),
        borderRadius: BorderRadius.circular(8),
        color: Colors.blue.withOpacity(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File info
          Row(
            children: [
              Icon(
                isVideo ? Icons.videocam : Icons.image,
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      isVideo ? 'Video' : 'Image',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Compression preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                // Original size
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Original Size:',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      _formatBytes(fileSize),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Arrow
                const Center(
                  child: Icon(Icons.arrow_downward, color: Colors.grey),
                ),

                const SizedBox(height: 12),

                // Estimated compressed size
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'After Compression:',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      _formatBytes(estimatedCompressed),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Compression ratio
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: ratio / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      ratio > 70 ? Colors.green : Colors.orange,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Compression Ratio:',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '${ratio.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ratio > 70 ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Info message
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isVideo
                        ? 'Video will be compressed to 720p with optimized bitrate'
                        : 'Image will be converted to WebP format for better compression',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),

          // Actual compression data (if available from backend)
          if (compressionData != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Actual Compression Results:',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Original: ${compressionData!['originalSize']}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Compressed: ${compressionData!['compressedSize']}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Saved: ${compressionData!['ratio']}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
