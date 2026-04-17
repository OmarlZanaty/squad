import 'package:flutter/material.dart';

class FacebookLikeIcon extends StatelessWidget {
  final bool isLiked;
  final double size;
  final Color? color; // Add color parameter

  const FacebookLikeIcon({
    super.key,
    this.isLiked = false,
    this.size = 24,
    this.color, // Optional color parameter
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
      color: isLiked ? (color ?? Colors.blue) : Colors.grey, // Use provided color or default to blue
      size: size,
    );
  }
}
