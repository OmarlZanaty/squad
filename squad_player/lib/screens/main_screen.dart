import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_localizations.dart';
import '../utils/app_colors.dart';
import '../config/app_config.dart';
import 'statistics_screen.dart';
import 'profile_edit_screen.dart';
import 'feed_screen.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _currentIndex = 2;
  DateTime? _lastPressedAt;
  int? _pendingPostId;

  late final List<Widget> _screens = [
    FeedScreen(scrollToPostId: _pendingPostId),
    const ProfileEditScreen(),
    const StatisticsScreen(),
    const ChatScreen(),
    const SettingsScreen(),
  ];

  // ── Called from NotificationScreen ────────────────────────────────────────
  void navigateToFeed(int postId) {
    setState(() {
      _pendingPostId = postId;
      _currentIndex  = 0;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _pendingPostId = null);
    });
  }

  // ── Profile photo check (runs once per session) ───────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkProfilePhotoOnce();
    });
  }

  Future<void> _checkProfilePhotoOnce() async {
    final prefs = await SharedPreferences.getInstance();

    // Only show once per login session
    final alreadyShown = prefs.getBool('profile_photo_prompt_shown') ?? false;
    if (alreadyShown) return;

    final token  = prefs.getString('auth_token');
    final userId = prefs.getInt('user_id');
    if (token == null || userId == null) return;

    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/users/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return;
      if (!mounted) return;

      final data  = jsonDecode(res.body) as Map<String, dynamic>;
      final photo = data['profile_photo_url']?.toString() ?? '';

      if (photo.isEmpty || photo == 'null') {
        await prefs.setBool('profile_photo_prompt_shown', true);
        _showProfilePhotoPrompt();
      }
    } catch (e) {
      debugPrint('[MainScreen] Profile check failed (non-blocking): $e');
    }
  }

  void _showProfilePhotoPrompt() {
    if (!mounted) return;
    final loc = AppLocalizations.of(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Avatar placeholder
              CircleAvatar(
                radius: 40,
                backgroundColor:
                (isDark ? AppColors.darkAccent : AppColors.primary).withOpacity(0.15),
                child: Icon(
                  Icons.camera_alt,
                  size: 36,
                  color: isDark ? AppColors.darkAccent : AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                loc?.tr('complete_profile_title') ?? 'أضف صورة شخصية',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                loc?.tr('profile_photo_prompt_desc') ??
                    'صورتك الشخصية تساعد المدربين والمسؤولين على التعرف عليك بسرعة.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // CTA
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    // Navigate to profile edit tab
                    setState(() => _currentIndex = 1);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: isDark ? AppColors.darkAccent : AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    loc?.tr('add_photo') ?? 'إضافة صورة الآن',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Skip
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  loc?.tr('skip') ?? 'ليس الآن',
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Back press handler ────────────────────────────────────────────────────
  Future<bool> _handleBackPress() async {
    final now = DateTime.now();
    const maxDuration = Duration(seconds: 2);

    final isWarning = _lastPressedAt == null ||
        now.difference(_lastPressedAt!) > maxDuration;

    if (isWarning) {
      _lastPressedAt = now;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.tr('press_back_again_to_exit') ??
                'Press back again to exit',
            textAlign: TextAlign.center,
          ),
          duration: maxDuration,
        ),
      );
      return false;
    }
    return true;
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc    = AppLocalizations.of(context)!;

    return WillPopScope(
      onWillPop: _handleBackPress,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            boxShadow: [
              BoxShadow(
                color: isDark ? AppColors.shadowDark : AppColors.shadow,
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              height: 65,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home,
                    label: loc.tr('feed'),
                    index: 0,
                    currentIndex: _currentIndex,
                    onTap: (i) => setState(() => _currentIndex = i),
                    isDark: isDark,
                  ),
                  _NavItem(
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: loc.tr('profile'),
                    index: 1,
                    currentIndex: _currentIndex,
                    onTap: (i) => setState(() => _currentIndex = i),
                    isDark: isDark,
                  ),
                  _NavItem(
                    icon: Icons.bar_chart_outlined,
                    activeIcon: Icons.bar_chart,
                    label: loc.tr('statistics'),
                    index: 2,
                    currentIndex: _currentIndex,
                    onTap: (i) => setState(() => _currentIndex = i),
                    isDark: isDark,
                  ),
                  _NavItem(
                    icon: Icons.chat_bubble_outline,
                    activeIcon: Icons.chat_bubble,
                    label: loc.tr('chat'),
                    index: 3,
                    currentIndex: _currentIndex,
                    onTap: (i) => setState(() => _currentIndex = i),
                    isDark: isDark,
                  ),
                  _NavItem(
                    icon: Icons.settings_outlined,
                    activeIcon: Icons.settings,
                    label: loc.tr('settings'),
                    index: 4,
                    currentIndex: _currentIndex,
                    onTap: (i) => setState(() => _currentIndex = i),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Nav item helper ───────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final void Function(int) onTap;
  final bool isDark;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final selected = index == currentIndex;
    final color    = selected
        ? (isDark ? AppColors.darkAccent : AppColors.primary)
        : (isDark ? Colors.white54 : Colors.black45);

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}