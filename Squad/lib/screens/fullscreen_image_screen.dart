import 'package:flutter/material.dart';

class FullscreenImageScreen extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const FullscreenImageScreen({
    super.key,
    required this.imageUrl,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Tap anywhere closes
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Center(
                  child: Hero(
                    tag: heroTag,
                    child: InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 5.0,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
