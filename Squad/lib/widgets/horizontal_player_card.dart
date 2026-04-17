import 'package:flutter/material.dart';
import 'package:squad/models/user.dart';
import 'package:squad/utils/app_colors.dart';

class HorizontalPlayerCard extends StatelessWidget {
  final User player;
  final VoidCallback? onTap;

  const HorizontalPlayerCard({
    super.key,
    required this.player,
    this.onTap,
  });

  String get _getFullImageUrl {
    if (player.profilePhotoUrl == null || player.profilePhotoUrl!.isEmpty) {
      return '';
    }
    if (player.profilePhotoUrl!.startsWith('http')) {
      return player.profilePhotoUrl!;
    }
    return 'http://187.124.37.68:3000${player.profilePhotoUrl}';
  }

  String _getCountryFlag(String? country) {
    if (country == null) return '';
    final Map<String, String> countryFlags = {
      'Egypt': '🇪🇬',
      'Tunisia': '🇹🇳',
      'South Africa': '🇿🇦',
      'Morocco': '🇲🇦',
    };
    return countryFlags[country] ?? '🌍';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 320,
        height: 180, // Fixed height for horizontal card
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1a2332),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            // Left Side - Image
            Container(
              width: 130,
              height: 180,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
                child: _getFullImageUrl.isNotEmpty
                    ? Image.network(
                  _getFullImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF2a3442),
                    child: const Icon(Icons.person, size: 50, color: Colors.white24),
                  ),
                )
                    : Container(
                  color: const Color(0xFF2a3442),
                  child: const Icon(Icons.person, size: 50, color: Colors.white24),
                ),
              ),
            ),
            // Right Side - Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      player.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(_getCountryFlag(player.country), style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(
                          player.country ?? 'Unknown',
                          style: const TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      player.position ?? 'Position not set',
                      style: const TextStyle(fontSize: 14, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
