import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/progressive_image_widget.dart';

class MediaGridWidget extends StatelessWidget {
  final List<Map<String, dynamic>> mediaList;
  final Function(int) onDelete;

  const MediaGridWidget({
    Key? key,
    required this.mediaList,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: mediaList.length,
      itemBuilder: (context, index) {
        final media = mediaList[index];
        final isVideo = media['type'] == 'video';
        final imageUrl = media['imageUrls']?['thumbnail'] ?? media['url'];
        final lqip = media['imageUrls']?['lqip'];

        return GestureDetector(
          onTap: () => _showMediaPreview(context, media),
          onLongPress: () => _showMediaOptions(context, media),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image or video thumbnail
              if (imageUrl != null)
                lqip != null
                    ? ProgressiveImageWidget(
                        imageUrl: imageUrl,
                        lqipData: lqip,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.error),
                        ),
                      )
              else
                Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.image_not_supported),
                ),

              // Video badge
              if (isVideo)
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.videocam,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),

              // Delete button on long press
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => onDelete(media['id']),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
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
    );
  }

  void _showMediaPreview(BuildContext context, Map<String, dynamic> media) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (media['type'] == 'image')
              Image.network(media['imageUrls']?['large'] ?? media['url'])
            else
              Text('Video: ${media['url']}'),
            const SizedBox(height: 16),
            Text('ID: ${media['id']}'),
            Text('Type: ${media['type']}'),
            if (media['size'] != null) Text('Size: ${media['size']}'),
            if (media['uploadedAt'] != null) Text('Date: ${media['uploadedAt']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showMediaOptions(BuildContext context, Map<String, dynamic> media) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Details'),
            onTap: () {
              Navigator.pop(context);
              _showMediaPreview(context, media);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              onDelete(media['id']);
            },
          ),
        ],
      ),
    );
  }
}
