import 'package:flutter/material.dart';
import 'package:squad/utils/app_colors.dart';
import 'package:squad/utils/app_localizations.dart';
import 'package:squad/screens/settings_screen.dart';
import 'package:squad/screens/feed_screen.dart';
import 'package:squad/screens/home_screen.dart';
import 'package:squad/screens/chat_screen.dart';
import 'package:squad/screens/profile_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({
    super.key,
    this.initialIndex = 2, // Default to Home (middle)
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  // Screens list: Settings, Feed, Home, Messages, Profile
  final List<Widget> _screens = [
    const SettingsScreen(),
    const FeedScreen(),
    const HomeScreen(),
    const ChatScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
      child: IndexedStack(
      index: _currentIndex,
      children: _screens,
    ),
    ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
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
            iconSize: 26, // fixes disappearing icons on some Android devices
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: isDark ? AppColors.cardDark : Colors.white,
            selectedItemColor:
            isDark ? AppColors.darkModeAccent : AppColors.primary,
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
        ),
      ),
      );
  }
}
