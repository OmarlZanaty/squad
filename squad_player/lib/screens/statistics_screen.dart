import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:squad_player/screens/profile_edit_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_top_bar.dart';
import 'package:squad_player/utils/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/app_colors.dart';
import 'dart:math' as math;
import 'followers_screen.dart';
import 'package:intl/intl.dart' as intl;
import 'package:squad_player/config/app_config.dart';
import 'package:squad_player/screens/notification_screen.dart';
import 'package:squad_player/services/api_service.dart';

import 'main_screen.dart';

enum _Period { week, month, year, all, custom }

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  _Period _selectedPeriod = _Period.all;
  int _unreadNotifications = 0;
  DateTimeRange? _selectedRange;

  void _updateRangeFromPeriod(_Period period) {
    final now = DateTime.now();
    switch (period) {
      case _Period.week:
        _selectedRange = DateTimeRange(
          start: now.subtract(const Duration(days: 7)),
          end: now,
        );
        break;
      case _Period.month:
        _selectedRange = DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now,
        );
        break;
      case _Period.year:
        _selectedRange = DateTimeRange(
          start: now.subtract(const Duration(days: 365)),
          end: now,
        );
        break;
      case _Period.all:
      case _Period.custom:
      // For 'all', null means no date filter (backend returns all time)
      // For 'custom', _selectedRange is set by the date picker directly
        if (period == _Period.all) _selectedRange = null;
        break;
    }
  }





  @override
  void initState() {
    super.initState();
    // ✅ Default = all time (no range filter)
    _selectedPeriod = _Period.all;
    _selectedRange  = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStatistics();
      _loadUnreadNotifications();
    });
  }



  bool _profileDialogShown = false;

  bool _isProfileComplete(Map<String, dynamic> data) {
    bool hasText(dynamic v) => v != null && v.toString().trim().isNotEmpty;

    // ✅ match your backend response keys
    final name = data['name']; // <-- your API uses "name"
    final country = data['country'];
    final position = data['position'];
    final phone = data['phone'];
    final photo = data['profile_photo_url'] ?? data['profilePhotoUrl'];

    // ✅ Only require what actually exists in your response
    return hasText(name) &&
        hasText(country) &&
        hasText(position) &&
        hasText(phone) &&
        hasText(photo);
  }


  Future<void> _showCompleteProfileDialogAndGo() async {
    if (!mounted) return;
    if (_profileDialogShown) return;
    _profileDialogShown = true;

    final loc = AppLocalizations.of(context);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(loc?.tr('complete_profile_title') ?? 'Complete your profile'),
        content: Text(
          loc?.tr('complete_profile_message') ??
              'Please complete your profile information to view statistics.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);

              // ✅ Redirect to profile screen
              // CHANGE THIS to your real profile screen widget
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
              );
            },
            child: Text(loc?.tr('ok') ?? 'OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _openWhatsApp() async {
    const String phoneE164 = '201003100623';

    // 1) Try open WhatsApp app
    final Uri scheme = Uri.parse('whatsapp://send?phone=$phoneE164');
    try {
      final ok = await launchUrl(scheme, mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (_) {}

    // 2) Fallback: open wa.me in browser (works even if canLaunchUrl is false sometimes)
    final Uri web = Uri.parse('https://wa.me/$phoneE164');
    try {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم العثور على WhatsApp أو المتصفح')),
        );
      }
    }
  }


  void _showContactOptions() {
    const String localPhone = '01003100623';
    const String phoneE164 = '201003100623'; // 2 + (01003100623 بدون 0)

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'تواصل معنا',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 20),

              // 📞 Call
              ListTile(
                leading: Icon(Icons.phone, color: AppColors.primary),
                title: const Text('اتصال هاتفي'),
                onTap: () async {
                  Navigator.pop(context);
                  final uri = Uri.parse('tel:$localPhone');
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),

              // 💬 WhatsApp
              // WhatsApp
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green),
                title: const Text('واتساب'),
                onTap: () async {
                  Navigator.pop(context);
                  await _openWhatsApp();
                },
              ),

            ],
          ),
        );
      },
    );
  }



  Future<void> _loadUnreadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null) {
        final response = await ApiService.getUnreadNotificationCount(token);
        if (response['success'] == true) {
          if (mounted) {
            setState(() {
              _unreadNotifications = response['count'] ?? 0;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading unread notifications: $e');
    }
  }

  Future<void> _loadStatistics() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      // Optional: Clear old stats so the user sees they are refreshing
      // _stats = {};
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userId = prefs.getInt('user_id');

      if (userId == null || token == null) {
        setState(() => _isLoading = false);
        return;
      }

      String url = '${AppConfig.apiBaseUrl}/users/$userId';
      if (_selectedRange != null) {
        String start = intl.DateFormat('yyyy-MM-dd').format(_selectedRange!.start);
        String end = intl.DateFormat('yyyy-MM-dd').format(_selectedRange!.end);
        url += '?startDate=$start&endDate=$end';
      }

      final response = await http.get(
        Uri.parse(url ),
        headers: {
          'Authorization': 'Bearer $token',
          'Cache-Control': 'no-cache', // Prevent cached results
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _stats = {
              'posts': data['post_count'] ?? 0,
              'followers': data['follower_count'] ?? 0,
              'following': data['following_count'] ?? 0,
              'likes': data['total_likes'] ?? 0,
              'comments': data['total_comments'] ?? 0,
              'shares': data['total_shares'] ?? 0,
              'views': data['total_views'] ?? 0,
              'profileViews': data['profile_views_count'] ?? 0,
              'rating': (data['rating'] ?? 0.0).toDouble(),
              'reach': _calculateReach(data),
            };
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }



// Fixed _showDateRangePicker method with proper dark mode support
// Replace the existing method in your StatisticsScreen

  Future<void> _showDateRangePicker() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final firstDate = DateTime(2020);
    final lastDate  = DateTime.now();

    DateTimeRange? initialRange;
    if (_selectedRange != null) {
      final s = _selectedRange!.start.isBefore(firstDate) ? firstDate : _selectedRange!.start;
      final e = _selectedRange!.end.isAfter(lastDate) ? lastDate : _selectedRange!.end;
      if (!s.isAfter(e)) initialRange = DateTimeRange(start: s, end: e);
    }
    initialRange ??= DateTimeRange(
      start: lastDate.subtract(const Duration(days: 7)),
      end: lastDate,
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: initialRange,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (ctx, child) => Theme(
        data: isDark
            ? ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.darkAccent,
            onPrimary: Colors.white,
            surface: const Color(0xFF1E1E2E),
          ),
        )
            : ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked == null || !mounted) return;

    final normalized = DateTimeRange(
      start: DateTime(picked.start.year, picked.start.month, picked.start.day),
      end:   DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
    );

    setState(() {
      _selectedRange  = normalized;
      _selectedPeriod = _Period.custom; // ✅ Mark as custom so buttons deselect
    });

    await _loadStatistics();
  }



  int _calculateReach(Map<String, dynamic> data) {
    //final views = data['total_views'] ?? data['views_count'] ?? 0;
    final likes = data['total_likes'] ?? data['likes_count'] ?? 0;
    final comments = data['total_comments'] ?? data['comments_count'] ?? 0;
    final shares = data['total_shares'] ?? data['shares_count'] ?? 0;

    final views = data['total_views'] ?? 0;
    final profileViews = data['profile_views_count'] ?? 0;
    return views + profileViews;

    // ✅ DO NOT add profileViews again
    return views + likes + comments + shares;
  }



  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70),
        child: SafeArea(
          child: Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: isDark ? AppColors.shadowDark : AppColors.shadow,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left - Notification icon with badge
                Stack(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.notifications_outlined,
                        size: 28,
                        color: isDark ? Colors.white : AppColors.black,
                      ),
                      onPressed: () async {
                        // 1. Open notifications and wait for a postId
                        final postId = await Navigator.push<int>(
                          context,
                          MaterialPageRoute(builder: (context) => const NotificationScreen()),
                        );

                        // 2. Refresh unread count
                        _loadUnreadNotifications();

                        // 3. ✅ If a postId was returned, tell MainScreen to switch to Feed
                        if (postId != null && mounted) {
                          final mainState = context.findAncestorStateOfType<MainScreenState>();
                          if (mainState != null) {
                            mainState.navigateToFeed(postId);
                          } else {
                            // Fallback: If for some reason MainScreenState isn't found,
                            // you might be in a different navigation stack.
                            print("MainScreenState not found!");
                          }
                        }
                      },

                    ),
                    if (_unreadNotifications > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkAccent : AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          constraints: BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Center(
                            child: Text(
                              _unreadNotifications > 99 ? '99+' : _unreadNotifications.toString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                // Center - Logo
                Expanded(
                  child: Center(
                    child: Image.asset(
                      'assets/images/logo3.png',
                      height: 140,
                      errorBuilder: (context, error, stackTrace) {
                        return Text(
                          'SQUAD',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.black,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Right - Phone/contact icon
                IconButton(
                  icon: Image.asset(
                    isDark ? 'assets/images/ringing_phone_white.png' : 'assets/images/ringing_phone_black.png',
                    width: 28,
                    height: 28,
                  ),
                  onPressed: _showContactOptions,

                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _selectedPeriod = _Period.all;
            _selectedRange = null;
          });
          await _loadStatistics();
        },
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20),
              // Period selector with calendar icon
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    // Calendar icon button on the RIGHT (in Arabic RTL layout)
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? AppColors.shadowDark : AppColors.shadow,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.calendar_today,
                          size: 24,
                          color: isDark ? AppColors.darkAccent : AppColors.primary,
                        ),
                        onPressed: _showDateRangePicker,
                        tooltip: 'اختر نطاق التاريخ',
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildPeriodSelector(isDark),
                    ),
                  ],
                ),
              ),
              _buildReachCard(isDark),
              SizedBox(height: 10),
              _buildEngagementStats(isDark),
              // _buildPerformanceMetrics(isDark),
              SizedBox(height: 120), // Space for bottom nav
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 60, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.tr('statistics'),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              SizedBox(height: 4),
/*              Text(
                AppLocalizations.of(context)!.tr('track_your_performance'),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),*/
            ],
          ),
          IconButton(
            onPressed: _showDateRangePicker,
            icon: Icon(Icons.calendar_today, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(bool isDark) {
    final loc = AppLocalizations.of(context)!;

    // Stable enum → label mapping (never breaks on language change)
    final periods = <_Period, String>{
      _Period.all:   loc.tr('all_time'),
      _Period.week:  loc.tr('week'),
      _Period.month: loc.tr('month'),
      _Period.year:  loc.tr('year'),
    };

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            // Period chips
            ...periods.entries.map((entry) {
              final isSelected = _selectedPeriod == entry.key;
              return GestureDetector(
                onTap: () async {
                  setState(() {
                    _selectedPeriod = entry.key;
                    _updateRangeFromPeriod(entry.key);
                  });
                  await _loadStatistics();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? AppColors.darkAccent : AppColors.primary)
                        : (isDark ? AppColors.cardDark : Colors.white.withOpacity(0.9)),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: isSelected
                        ? [
                      BoxShadow(
                        color: (isDark ? AppColors.darkAccent : AppColors.primary)
                            .withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                        : [],
                  ),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black87),
                      fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }),

            // Custom date chip — shows selected range if active
            GestureDetector(
              onTap: () async {
                await _showDateRangePicker();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedPeriod == _Period.custom
                      ? (isDark ? AppColors.darkAccent : AppColors.primary)
                      : (isDark ? AppColors.cardDark : Colors.white.withOpacity(0.9)),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: _selectedPeriod == _Period.custom
                      ? [
                    BoxShadow(
                      color: (isDark ? AppColors.darkAccent : AppColors.primary)
                          .withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.date_range,
                      size: 14,
                      color: _selectedPeriod == _Period.custom
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black54),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _selectedPeriod == _Period.custom && _selectedRange != null
                          ? '${_selectedRange!.start.day}/${_selectedRange!.start.month} - '
                          '${_selectedRange!.end.day}/${_selectedRange!.end.month}'
                          : loc.tr('custom') ?? 'مخصص',
                      style: TextStyle(
                        color: _selectedPeriod == _Period.custom
                            ? Colors.white
                            : (isDark ? Colors.white : Colors.black87),
                        fontWeight: _selectedPeriod == _Period.custom
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 14,
                      ),
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


  Widget _buildReachCard(bool isDark) {
    final totalReach = _stats['reach'] ?? 0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [Color(0xFF26A69A), Color(0xFF00897B)]  // Teal gradient for dark mode
              : [Color(0xFF2BC9A8), Color(0xFF2BC9A8)],  // Green gradient for light mode
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Color(0xFF26A69A) : Color(0xFF2BC9A8)).withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context)!.tr('total_reach'),
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.trending_up, color: Color(0xFF2BC9A8), size: 20),
                  SizedBox(width: 4),
                  Text(
                    '+12%',
                    style: TextStyle(color: Color(0xFF2BC9A8), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 20),
          Column(
            children: [
              Icon(Icons.visibility, color: Colors.white, size: 32),
              SizedBox(height: 8),
              Text(
                _formatNumber(totalReach),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildReachItem(AppLocalizations.of(context)!.tr('likes'), _stats['likes'] ?? 0, Colors.white),
              _buildReachItem(AppLocalizations.of(context)!.tr('comments'), _stats['comments'] ?? 0, Colors.white),
              _buildReachItem(AppLocalizations.of(context)!.tr('shares'), _stats['shares'] ?? 0, Colors.white),
              _buildReachItem(AppLocalizations.of(context)!.tr('posts'), _stats['posts'] ?? 0, Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReachItem(String label, int value, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            label == AppLocalizations.of(context)!.tr('likes') ? Icons.favorite :
            label == AppLocalizations.of(context)!.tr('comments') ? Icons.comment :
            label == AppLocalizations.of(context)!.tr('shares') ? Icons.share :
            label == AppLocalizations.of(context)!.tr('posts')? Icons.article_outlined // ✅ posts icon
                : Icons.visibility,
            color: color,
            size: 20,
          ),
        ),
        SizedBox(height: 8),
        Text(
          _formatNumber(value),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildEngagementStats(bool isDark) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /*Text(
            AppLocalizations.of(context)!.tr('engagement'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),*/
          SizedBox(height: 16),
          Row(
            children: [
              /*Expanded(
                child: _buildStatCard(
                  AppLocalizations.of(context)!.tr('posts'),
                  _stats['posts'].toString(),
                  Icons.article,
                  isDark ? Color(0xFF26A69A) : Color(0xFF2BC9A8),
                  isDark,
                ),
              ),*/
              SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    // Navigate to followers screen showing ALL followers (scouts, guests, players)
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FollowersScreen(),
                      ),
                    );
                  },
                  child: _buildStatCard(
                    AppLocalizations.of(context)!.tr('followers1'),
                    _formatNumber(_stats['followers'] ?? 0),
                    Icons.people,
                    Color(0xFF26A69A),
                    isDark,
                  ),
                ),
              ),

              SizedBox(width: 12),

              Expanded(
                child: _buildStatCard(
                  AppLocalizations.of(context)!.tr('rating'),
                  (_stats['rating'] is num ? (_stats['rating'] as num).toDouble() : 0.0).toStringAsFixed(1),
                  Icons.star,
                  Color(0xFFFFA726),
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark.withOpacity(0.5) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, int value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
        Text(
          _formatNumber(value),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }
}
