import 'package:flutter/material.dart';
import 'package:squad/utils/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
class AdCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  // ✅ SAME default image for all ads if no image uploaded
  static const String kDefaultAsset = 'assets/images/default_ad.jpg';

  const AdCard({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.backgroundColor,
    this.onTap,
  });

  bool get _hasImage => (imageUrl ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          gradient: backgroundColor != null
              ? LinearGradient(
            colors: [backgroundColor!, backgroundColor!.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // ✅ Background Image: network OR default asset
              Positioned.fill(
                child: _hasImage
                    ? CachedNetworkImage(
                  imageUrl: imageUrl!.trim(),
                  fit: BoxFit.cover,
                  memCacheWidth: 800,
                  memCacheHeight: 400,
                  placeholder: (context, url) =>
                  const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) =>
                      Image.asset(kDefaultAsset, fit: BoxFit.cover),
                )
                    : Image.asset(
                  kDefaultAsset,
                  fit: BoxFit.cover,
                ),
              ),

              // Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,
                        Colors.black.withOpacity(0.6),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}