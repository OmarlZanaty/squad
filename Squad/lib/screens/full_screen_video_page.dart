import 'package:flutter/material.dart';
import 'package:squad/widgets/video_player_widget.dart';

class FullScreenVideoPage extends StatelessWidget {
  final String videoUrl;
  const FullScreenVideoPage({super.key, required this.videoUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: VideoPlayerWidget(videoUrl: videoUrl),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
