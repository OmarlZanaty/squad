import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_localizations.dart';
import 'package:intl/intl.dart';

class PlayerProfileScreen extends StatefulWidget {
  final int userId;
  const PlayerProfileScreen({super.key, required this.userId});

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  bool _isLoading = true;

  User? _user;
  bool _isFollowing = false;

  String? _token;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _token = await AuthService.getToken();     // ✅ correct source
    _currentUserId = await AuthService.getUserId();

    if (_token == null || _token!.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    await Future.wait([
      _loadUser(),
      _loadIsFollowing(),
    ]);

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadUser() async {
    try {
      // ✅ uses AppConfig.apiBaseUrl internally (no hardcode)
      final res = await ApiService.getUserProfile(
        token: _token!,
        userId: widget.userId,
      );

      // res might be:
      // 1) {success:true, user:{...}}
      // 2) {data:{...}}
      // 3) direct user map {...}
      Map<String, dynamic>? userJson;

      if (res is Map<String, dynamic>) {
        if (res['user'] is Map) {
          userJson = Map<String, dynamic>.from(res['user']);
        } else if (res['data'] is Map) {
          userJson = Map<String, dynamic>.from(res['data']);
        } else if (res.containsKey('id') || res.containsKey('name')) {
          userJson = res;
        }
      }

      if (userJson != null) {
        if (mounted) setState(() => _user = User.fromJson(userJson!));
      } else {
        // Debug hint (shows what backend returned)
        debugPrint('User profile response unexpected: $res');
      }
    } catch (e) {
      debugPrint('Failed to load user profile: $e');
    }
  }

  Future<void> _loadIsFollowing() async {
    if (_token == null || _currentUserId == null) return;

    try {
      final list = await ApiService.getFollowing(
        token: _token!,
        userId: _currentUserId!,
      );

      final ids = list.map((e) {
        if (e is Map && e['id'] != null) return (e['id'] as num).toInt();
        return -1;
      }).toList();

      if (mounted) setState(() => _isFollowing = ids.contains(widget.userId));
    } catch (e) {
      debugPrint('Failed to load following state: $e');
    }
  }

  Future<void> _toggleFollow() async {
    if (_token == null) return;

    final old = _isFollowing;
    setState(() => _isFollowing = !old); // optimistic

    try {
      if (old == true) {
        // was following -> unfollow
        final res = await ApiService.unfollowUser(token: _token!, userId: widget.userId);
        if (res['success'] == false) throw Exception(res['message'] ?? 'unfollow failed');
      } else {
        // was not following -> follow
        final res = await ApiService.followUser(token: _token!, userId: widget.userId);
        if (res['success'] == false) throw Exception(res['message'] ?? 'follow failed');
      }
    } catch (e) {
      setState(() => _isFollowing = old); // revert
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        elevation: 0,
        title: Text(_user?.name ?? ''),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_user == null)
          ? Center(
        child: Text(
          AppLocalizations.of(context)?.tr('user_not_found') ?? 'User not found',
        ),
      )
          : SingleChildScrollView(
        child: Column(
          children: [
            _buildCover(isDark),
            _buildAvatar(isDark),
            const SizedBox(height: 12),
            _buildNameAndMeta(isDark),
            const SizedBox(height: 16),

            if (_currentUserId != widget.userId)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _toggleFollow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isFollowing ? Colors.grey[400] : AppColors.primary,
                      foregroundColor: _isFollowing ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _isFollowing
                          ? (AppLocalizations.of(context)?.tr('following') ?? 'Following')
                          : (AppLocalizations.of(context)?.tr('follow') ?? 'Follow'),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildInfoCards(isDark),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // NOTE: these fields depend on your User model keys.
  // If your User model doesn't have coverPhotoUrl/profilePhotoUrl,
  // replace them with the correct properties.
  Widget _buildCover(bool isDark) {
    final cover = (_user?.coverPhotoUrl ?? '');
    return Container(
      height: 200,
      width: double.infinity,
      color: isDark ? AppColors.cardDark : Colors.grey[300],
      child: cover.isNotEmpty
          ? Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())
          : Center(child: Icon(Icons.photo, size: 50, color: Colors.grey[500])),
    );
  }

  Widget _buildAvatar(bool isDark) {
    final avatar = (_user?.profilePhotoUrl ?? '');
    return Transform.translate(
      offset: const Offset(0, -50),
      child: CircleAvatar(
        radius: 60,
        backgroundColor: AppColors.greyLight,
        backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
        child: avatar.isEmpty ? Icon(Icons.person, size: 60, color: Colors.grey[600]) : null,
      ),
    );
  }

  Widget _buildNameAndMeta(bool isDark) {
    return Transform.translate(
      offset: const Offset(0, -40),
      child: Column(
        children: [
          Text(
            _user!.name,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            [
              if ((_user!.country ?? '').isNotEmpty) _user!.country!,
              if ((_user!.position ?? '').isNotEmpty) _user!.position!,
            ].join(' • '),
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }
  String _typeLabel(BuildContext context, String type) {
    final t = type.trim().toLowerCase();

    // If you want localization keys:
    // user_type_guest, user_type_player, ...
    final key = 'user_type_$t';

    // If you DO NOT have these keys yet, fallback to readable values
    final localized = AppLocalizations.of(context)?.tr(key);
    if (localized != null && localized != key) return localized;

    // fallback (English)
    switch (t) {
      case 'guest':
        return 'Guest';
      case 'player':
        return 'Player';
      case 'admin':
        return 'Admin';
      default:
        return type;
    }
  }
  Widget _buildInfoCards(bool isDark) {
    return Column(
      children: [
        _infoRow(
          isDark,
          Icons.badge,
          AppLocalizations.of(context)?.tr('type') ?? 'Type',
          _typeLabel(context, _user!.type),
        ),      ],
    );
  }

  Widget _infoRow(bool isDark, IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: isDark ? AppColors.darkAccent : AppColors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                const SizedBox(height: 4),
                Text(value.isNotEmpty ? value : '-', style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}