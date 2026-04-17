import 'package:flutter/material.dart';
import 'package:squad/models/user.dart';
import 'package:squad/utils/app_colors.dart';
import 'package:squad/widgets/player_card.dart';
import 'package:squad/screens/player_profile_screen.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

class CategoryPlayersScreen extends StatelessWidget {
  final String categoryTitle;
  final List<User> players;
  final IconData categoryIcon;
  final Color categoryColor;

  const CategoryPlayersScreen({
    super.key,
    required this.categoryTitle,
    required this.players,
    required this.categoryIcon,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : AppColors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(categoryIcon, color: categoryColor, size: 24),
            const SizedBox(width: 8),
            Text(
              categoryTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: players.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 80,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'لا يوجد لاعبين في هذه الفئة',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: players.length,
        itemBuilder: (context, index) {
          final player = players[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: PlayerCard(
              player: player,
              onTap: () async {
                debugPrint('✅ Category tap fired id=${player.id} name=${player.name}');

                final token = await AuthService.getToken();
                debugPrint('✅ token exists? ${token != null}');

                if (token != null) {
                  try {
                    await ApiService.incrementProfileView(
                      token: token,
                      userId: player.id,
                    );
                    debugPrint('✅ incrementProfileView finished');
                  } catch (e) {
                    debugPrint('❌ incrementProfileView error: $e');
                  }
                }

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayerProfileScreen(userId: player.id),
                  ),
                );
              },


            ),
          );
        },
      ),
    );
  }
}
