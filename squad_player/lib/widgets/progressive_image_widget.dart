import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';

class ProgressiveImageWidget extends StatefulWidget {
  final String imageUrl;
  final String? lqipData;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Duration blurDuration;

  const ProgressiveImageWidget({
    Key? key,
    required this.imageUrl,
    this.lqipData,
    this.width = double.infinity,
    this.height = 200,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.blurDuration = const Duration(milliseconds: 500),
  }) : super(key: key);

  @override
  State<ProgressiveImageWidget> createState() => _ProgressiveImageWidgetState();
}

class _ProgressiveImageWidgetState extends State<ProgressiveImageWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _imageLoaded = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: widget.blurDuration,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _onImageLoaded() {
    if (!_imageLoaded) {
      setState(() {
        _imageLoaded = true;
      });
      _fadeController.forward();
    }
  }

  /// Decode base64 LQIP image
  Uint8List? _decodeLQIP() {
    if (widget.lqipData == null || widget.lqipData!.isEmpty) {
      return null;
    }

    try {
      // Remove data URI prefix if present
      String base64String = widget.lqipData!;
      if (base64String.contains(',')) {
        base64String = base64String.split(',')[1];
      }

      return base64Decode(base64String);
    } catch (e) {
      debugPrint('Error decoding LQIP: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lqipBytes = _decodeLQIP();

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey[200],
        child: Stack(
          fit: StackFit.expand,
          children: [
            // LQIP (Low Quality Image Placeholder) - Blurred version
            if (lqipBytes != null)
              Image.memory(
                lqipBytes,
                width: widget.width,
                height: widget.height,
                fit: widget.fit,
              )
            else
              Container(
                color: Colors.grey[300],
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),

            // Full quality image with fade animation
            FadeTransition(
              opacity: _fadeAnimation,
              child: CachedNetworkImage(
                imageUrl: widget.imageUrl,
                width: widget.width,
                height: widget.height,
                fit: widget.fit,

                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(
                      Icons.error_outline,
                      color: Colors.red,
                    ),
                  ),
                ),
                placeholder: (context, url) => Container(
                  color: Colors.transparent,
                ),
              ),
            ),

            // Loading indicator (shown while transitioning)
            if (!_imageLoaded)
              const Center(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Alternative: Simple Progressive Image without LQIP
class SimpleProgressiveImageWidget extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const SimpleProgressiveImageWidget({
    Key? key,
    required this.imageUrl,
    this.width = double.infinity,
    this.height = 200,
    this.fit = BoxFit.cover,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Container(
          color: Colors.grey[200],
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(
              Icons.error_outline,
              color: Colors.red,
            ),
          ),
        ),
      ),
    );
  }
}
