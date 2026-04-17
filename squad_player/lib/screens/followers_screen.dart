import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squad_player/screens/player_profile_screen.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../utils/app_colors.dart';
import '../utils/app_localizations.dart';

class FollowersScreen extends StatefulWidget {
  const FollowersScreen({super.key});

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<User> _followers = [];
  List<User> _following = [];
  bool _isLoadingFollowers = true;
  bool _isLoadingFollowing = true;

  @override
  void initState() {
    super.initState();
    print('FollowersScreen: initState called');
    _tabController = TabController(length: 2, vsync: this);
    _loadFollowers();
    _loadFollowing();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _translateCountry(String? country) {
    if (country == null || country.isEmpty) return '';
    final key = _countryKeyMap[country];
    if (key == null) return country; // fallback
    return AppLocalizations.of(context)!.tr(key);
  }

  String _translatePosition(String? position) {
    if (position == null || position.isEmpty) return '';
    final key = _positionKeyMap[position];
    if (key == null) return position; // fallback
    return AppLocalizations.of(context)!.tr(key);
  }

  // Country translation map
  final Map<String, String> _countryKeyMap = {
    'Egypt': 'egypt',
    'Saudi Arabia': 'saudi_arabia',
    'United Arab Emirates': 'uae',
    'Kuwait': 'kuwait',
    'Qatar': 'qatar',
    'Bahrain': 'bahrain',
    'Oman': 'oman',
    'Jordan': 'jordan',
    'Lebanon': 'lebanon',
    'Iraq': 'iraq',
  };

// Position translation map
  final Map<String, String> _positionKeyMap = {
    'Goalkeeper': 'goalkeeper',
    'Right Back': 'right_back',
    'Left Back': 'left_back',
    'Center Back': 'center_back',
    'Defensive Midfielder': 'defensive_midfielder',
    'Central Midfielder': 'central_midfielder',
    'Attacking Midfielder': 'attacking_midfielder',
    'Right Winger': 'right_winger',
    'Left Winger': 'left_winger',
    'Forward': 'forward',
    'Striker': 'striker',
  };


  Future<void> _loadFollowers() async {
    setState(() => _isLoadingFollowers = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userId = prefs.getInt('user_id'); // ✅ INT

      if (token == null || userId == null) {
        throw Exception('Not authenticated');
      }

      final list = await ApiService.getFollowers(
        token: token,
        userId: userId,
      );

      final followers = list
          .map((e) => User.fromJson(e as Map<String, dynamic>))
          .toList();

      setState(() {
        _followers = followers;
        _isLoadingFollowers = false;
      });
    } catch (e) {
      print('FollowersScreen: Error loading followers: $e');
      setState(() => _isLoadingFollowers = false);
    }
  }


  Future<void> _loadFollowing() async {
    setState(() => _isLoadingFollowing = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userId = prefs.getInt('user_id'); // ✅ INT

      if (token == null || userId == null) {
        throw Exception('Not authenticated');
      }

      final list = await ApiService.getFollowing(
        token: token,
        userId: userId,
      );

      final following = list
          .map((e) => User.fromJson(e as Map<String, dynamic>))
          .toList();

      setState(() {
        _following = following;
        _isLoadingFollowing = false;
      });
    } catch (e) {
      print('FollowersScreen: Error loading following: $e');
      setState(() => _isLoadingFollowing = false);
    }
  }


  Future<void> _toggleFollow(User user, bool isCurrentlyFollowing) async {
    // ✅ Optimistic update (remove immediately from following list)
    setState(() {
      if (isCurrentlyFollowing) {
        _following.removeWhere((u) => u.id == user.id);
      } else {
        // Optional: add locally so follower list shows "Following" instantly
        _following.add(user);
      }
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) throw Exception('Not authenticated');

      if (isCurrentlyFollowing) {
        await ApiService.unfollowUser(token: token, userId: user.id);
      } else {
        await ApiService.followUser(token: token, userId: user.id);
      }

      // ✅ IMPORTANT: await refresh so UI matches backend for sure
      await Future.wait([_loadFollowers(), _loadFollowing()]);
    } catch (e) {
      // If error, reload from server to revert safely
      await Future.wait([_loadFollowers(), _loadFollowing()]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.tr('error')}: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.tr('followers1'),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(
              text: '${AppLocalizations.of(context)!.tr('followers')} (${_followers.length})',
            ),
            Tab(
              text: '${AppLocalizations.of(context)!.tr('following')} (${_following.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFollowersList(isDark),
          _buildFollowingList(isDark),
        ],
      ),
    );
  }

  Widget _buildFollowersList(bool isDark) {
    if (_isLoadingFollowers) {
      return Center(child: CircularProgressIndicator());
    }

    if (_followers.isEmpty) {
      return _buildEmptyState(
        AppLocalizations.of(context)!.tr('no_followers_yet'),
        AppLocalizations.of(context)!.tr('no_followers_description'),
        Icons.people_outline,
        isDark,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFollowers,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _followers.length,
        itemBuilder: (context, index) {
          final user = _followers[index];
          // Check if we're following this user back
          final isFollowingBack = _following.any((u) => u.id == user.id);
          return _buildUserCard(user, isFollowingBack, isDark);
        },
      ),
    );
  }

  Widget _buildFollowingList(bool isDark) {
    if (_isLoadingFollowing) {
      return Center(child: CircularProgressIndicator());
    }

    if (_following.isEmpty) {
      return _buildEmptyState(
        AppLocalizations.of(context)!.tr('not_following_anyone'),
        AppLocalizations.of(context)!.tr('not_following_description'),
        Icons.person_add_outlined,
        isDark,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFollowing,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _following.length,
        itemBuilder: (context, index) {
          final user = _following[index];
          return _buildUserCard(user, true, isDark);
        },
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(User user, bool isFollowing, bool isDark) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(

        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlayerProfileScreen(userId: user.id),
            ),
          );
        },

        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.primary,
          backgroundImage: user.profilePhotoUrl != null && user.profilePhotoUrl!.isNotEmpty
              ? NetworkImage(user.profilePhotoUrl!)
              : null,
          child: user.profilePhotoUrl == null || user.profilePhotoUrl!.isEmpty
              ? Text(
            user.name[0].toUpperCase(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          )
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
           /* Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: user.type == 'player'
                    ? AppColors.primary.withOpacity(0.2)
                    : AppColors.secondary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                AppLocalizations.of(context)!.tr(user.type),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: user.type == 'player' ? AppColors.primary : AppColors.secondary,
                ),
              ),
            ),*/
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((user.country != null && user.country!.isNotEmpty) ||
                (user.position != null && user.position!.isNotEmpty))
              SizedBox(height: 4),
            if ((user.country != null && user.country!.isNotEmpty) ||
                (user.position != null && user.position!.isNotEmpty))
              Text(
                [
                  _translateCountry(user.country),
                  _translatePosition(user.position),
                ].where((s) => s.isNotEmpty).join(' • '),
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 12,
                ),
              )
            ,
            if (user.followersCount != null || user.followingCount != null)
              SizedBox(height: 4),
            if (user.followersCount != null || user.followingCount != null)
              Text(
                '${user.followersCount ?? 0} ${AppLocalizations.of(context)!.tr('followers')} • ${user.followingCount ?? 0} ${AppLocalizations.of(context)!.tr('following')}',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                ),
              ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _toggleFollow(user, isFollowing),
          style: ElevatedButton.styleFrom(
            backgroundColor: isFollowing ? Colors.grey[300] : AppColors.primary,
            foregroundColor: isFollowing ? Colors.black : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: Text(
            isFollowing
                ? AppLocalizations.of(context)!.tr('unfollow')
                : AppLocalizations.of(context)!.tr('follow'),
            style: TextStyle(fontSize: 12),
          ),
        ),
      ),
    );
  }
}
