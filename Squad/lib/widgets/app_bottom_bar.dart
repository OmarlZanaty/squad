import 'package:flutter/material.dart';
import 'package:squad/utils/app_colors.dart';
import 'package:squad/utils/app_localizations.dart';
import 'package:squad/screens/settings_screen.dart';
import 'package:squad/screens/feed_screen.dart';
import 'package:squad/screens/home_screen.dart';
import 'package:squad/screens/chat_screen.dart';
import 'package:squad/screens/profile_screen.dart';

class AppBottomBar extends StatelessWidget {
  final int currentIndex;

  const AppBottomBar({
    super.key,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: isDark ? AppColors.shadowDark : AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => _onTap(context, index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        selectedItemColor: isDark ? AppColors.darkModeAccent : AppColors.primary,
        unselectedItemColor: AppColors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            activeIcon: const Icon(Icons.settings),
            label: loc?.tr('settings') ?? 'Settings',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.article_outlined),
            activeIcon: const Icon(Icons.article),
            label: loc?.tr('feed') ?? 'Feed',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: loc?.tr('home') ?? 'Home',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.message_outlined),
            activeIcon: const Icon(Icons.message),
            label: loc?.tr('messages') ?? 'Messages',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: loc?.tr('profile') ?? 'Profile',
          ),
        ],
      ),
    );
  }

  void _onTap(BuildContext context, int index) {
    // Don't navigate if already on the same screen
    if (index == currentIndex) return;

    Widget screen;
    switch (index) {
      case 0:
        screen = const SettingsScreen();
        break;
      case 1:
        screen = const FeedScreen();
        break;
      case 2:
        screen = const HomeScreen();
        break;
      case 3:
        screen = const ChatScreen();
        break;
      case 4:
        screen = const ProfileScreen();
        break;
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }
}
