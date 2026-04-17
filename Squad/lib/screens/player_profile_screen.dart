import 'package:flutter/material.dart';
import 'package:squad/utils/app_colors.dart';
import 'package:squad/services/api_service.dart';
import 'package:squad/services/auth_service.dart';
import 'package:squad/models/user.dart';
import 'package:squad/models/post.dart';
import 'package:squad/widgets/post_card.dart';
import 'package:squad/screens/chat_conversation_screen.dart';
import 'package:squad/utils/app_localizations.dart';
import 'package:squad/utils/position_translator.dart';
import 'package:squad/widgets/report_content_sheet.dart';
import 'package:squad/widgets/block_user_dialog.dart';
import 'package:squad/screens/full_screen_video_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:squad/utils/share_links.dart';

class PlayerProfileScreen extends StatefulWidget {
  final int userId;

  const PlayerProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  User? _user;
  List<Post> _posts = [];
  bool _isLoading = true;
  bool _isFollowing = false;
  String? _token;
  int? _currentUserId;
  final Set<int> _viewedInProfile = <int>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _init();
  }

  Future<void> _init() async {
    await _loadData();
    await _recordProfileView();
  }

  Future<void> _recordProfileView() async {
    final token = await AuthService.getToken();
    final viewerId = await AuthService.getUserId();

    if (token == null) return;

    // prevent counting your own profile
    if (viewerId == widget.userId) return;

    try {
      await ApiService.incrementProfileView(
        token: token,
        userId: widget.userId,
      );
    } catch (e) {
      debugPrint("Profile view error: $e");
    }
  }

  Future<void> _loadData() async {
    _token = await AuthService.getToken();
    _currentUserId = await AuthService.getUserId();

    if (_token != null) {
      await Future.wait([
        _loadUserProfile(),
        _loadUserPosts(),
      ]);
    }
  }

  Future<void> _shareProfile() async {
    if (_user == null) return;

    final message =
        "Check out ${_user!.name}'s profile on Squad Player ⚽\n\n"
        "${ShareLinks.profileText(widget.userId)}\n\n"
        "Download the app:\n${ShareLinks.storeLink}";

    try {

      // ✅ record profile share
      await ApiService.recordProfileShare(
        profileUserId: widget.userId,
        platform: 'system',
      );

      // ✅ open share sheet
      await Share.share(message);

    } catch (e) {
      print("PROFILE SHARE ERROR: $e");
    }
  }

  Future<void> _loadUserProfile() async {
    if (_token == null) return;

    try {
      final result = await ApiService.getUserProfile(
        token: _token!,
        userId: widget.userId,
      );

      print('API Response: $result');

      Map<String, dynamic>? userResult;

      // Handle different response formats
      if (result['success'] == true && result['data'] != null) {
        userResult = result['data'];
      } else if (result['user'] != null) {
        userResult = result['user'];
      } else if (result['id'] != null) {
        // Direct user object
        userResult = result;
      }

      if (userResult != null) {
        print('User data: $userResult');
        print('is_following from API: ${result['is_following']} / ${result['data']?['is_following']} / ${userResult['is_following']}');
        print('follower_count: ${userResult['follower_count']}');

        setState(() {
          _user = User.fromJson(userResult!);
          // Check if current user is following this user (API uses is_following with value 1 or 0)
          _isFollowing = (result['is_following'] == 1 || result['is_following'] == true) ||
              (result['data']?['is_following'] == 1 || result['data']?['is_following'] == true) ||
              (userResult['is_following'] == 1 || userResult['is_following'] == true);
          _isLoading = false;
        });

        print('_isFollowing set to: $_isFollowing');
        print('Followers count in model: ${_user?.followersCount}');
      } else {
        print('User data not found in response');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading user: $e');
      setState(() => _isLoading = false);
    }
  }

  void _openImageFullScreen(String imageUrl, {String? heroTag}) {
    if (imageUrl.isEmpty) return;

    showGeneralDialog(
      context: context,
      barrierLabel: "ImageViewer",
      barrierDismissible: true, // tap outside closes
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: heroTag != null
                        ? Hero(
                      tag: heroTag,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          );
                        },
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image,
                          color: Colors.white,
                          size: 60,
                        ),
                      ),
                    )
                        : Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image,
                        color: Colors.white,
                        size: 60,
                      ),
                    ),
                  ),
                ),

                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (_, anim, __, child) {
        return FadeTransition(opacity: anim, child: child);
      },
    );
  }

  void _openAvatarFullScreen(String imageUrl, {required String heroTag}) {
    if (imageUrl.isEmpty) return;

    showGeneralDialog(
      context: context,
      barrierLabel: "AvatarViewer",
      barrierDismissible: true,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: Hero(
                    tag: heroTag,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.6),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: InteractiveViewer(
                          minScale: 1.0,
                          maxScale: 4.0,
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: MediaQuery.of(context).size.width * 0.85,
                            height: MediaQuery.of(context).size.width * 0.85,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const SizedBox(
                                width: 80,
                                height: 80,
                                child: CircularProgressIndicator(color: Colors.white),
                              );
                            },
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image,
                              color: Colors.white,
                              size: 60,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (_, anim, __, child) {
        return FadeTransition(opacity: anim, child: child);
      },
    );
  }



  Future<void> _loadUserPosts() async {
    if (_token == null) return;

    try {
      final result = await ApiService.getUserPosts(
        token: _token!,
        userId: widget.userId,
      );

      // ✅ debug AFTER result exists
      if (result is List) {
        debugPrint('👁️ getUserPosts first item: ${result.isNotEmpty ? result[0] : "EMPTY"}');

        final allPosts = result
            .map((json) => Post.fromJson(json as Map<String, dynamic>))
            .toList();

        setState(() {
          _posts = allPosts;
        });
      } else {
        debugPrint('👁️ getUserPosts unexpected type: ${result.runtimeType} data=$result');
      }
    } catch (e) {
      debugPrint('Error loading posts: $e');
    }
  }


  void _updatePostViews(int postId, int newViews) {
    setState(() {
      final i = _posts.indexWhere((p) => p.id == postId);
      if (i != -1) {
        _posts[i] = _posts[i].copyWith(views: newViews);
      }
    });
  }


  Future<void> _toggleFollow() async {
    if (_token == null) return;

    try {
      final response = _isFollowing
          ? await ApiService.unfollowUser(token: _token!, userId: widget.userId)
          : await ApiService.followUser(token: _token!, userId: widget.userId);

      print('Follow/Unfollow response: $response');

      // Check if the API call was successful
      if (response['success'] == true || response['success'] == null) {
        // Update the follow state only if successful
        setState(() => _isFollowing = !_isFollowing);

        // Reload the profile to get updated followers count
        await _loadUserProfile();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isFollowing ? 'تمت المتابعة' : 'تم إلغاء المتابعة'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        // API returned an error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'حدث خطأ'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      print('Follow/Unfollow error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _startChat() async {
    if (_token == null || _user == null) return;

    try {
      // Start or get existing chat with this user
      print('🚀 Starting chat with user ID: ${widget.userId}');
      final result = await ApiService.startChat(
        token: _token!,
        otherUserId: widget.userId,
      );

      print('📩 Start chat response: $result');

      // Check for both success and chatId (handles both new and existing chats)
      final chatId = result['chat_id'] ?? result['chatId'];
      print('🔑 Extracted chatId: $chatId');
      print('🧭 mounted: $mounted');
      if (chatId != null) {
        print('✅ ChatId is not null, navigating...');

        // Navigate to chat conversation screen
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatConversationScreen(
                chatId: chatId,
                otherUserName: _user!.name,
                otherUserPhoto: _getFullImageUrl(_user!.profilePhotoUrl),
              ),
            ),
          );
        }
      } else if (result['chat'] != null && result['chat']['id'] != null) {
        // Fallback for different response format
        final chatId = result['chat']['id'];
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatConversationScreen(
                chatId: chatId,
                otherUserName: _user!.name,
                otherUserPhoto: _getFullImageUrl(_user!.profilePhotoUrl),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'فشل بدء المحادثة'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      print('Start chat error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleReaction(int postId, String reactionType) async {
    if (_token == null) return;

    try {
      await ApiService.reactToPost(
        token: _token!,
        postId: postId,
        reactionType: reactionType,
      );
      // Reload posts to get updated reaction counts
      await _loadUserPosts();
    } catch (e) {
      print('Error reacting to post: $e');
    }
  }

  Future<void> _handleDeletePost(int postId) async {
    if (_token == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المنشور'),
        content: const Text('هل أنت متأكد من حذف هذا المنشور؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deletePost(token: _token!, postId: postId);
        await _loadUserPosts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف المنشور'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في حذف المنشور: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  String _getFullImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    return ApiService.toAbsoluteUrl(url); // ✅ uses the single correct base URL
  }

  bool _isPending(Post p) {
    final s = (p.status ?? '').toLowerCase();
    return s == 'pending' || s == '0';
  }

  /// "Active" = approved (and also allow empty status for old data if you want)
  bool _isActive(Post p) {
    final s = (p.status ?? '').toLowerCase();
    if (s.isEmpty) return true; // optional: treat missing status as active
    return s == 'approved' || s == 'active' || s == '1';
  }

  bool _isVideoPost(Post p) {
    final url = (p.mediaUrl ?? '').trim();
    if (url.isEmpty) return false;
    // Check media_type field first (most reliable)
    if ((p.mediaType ?? '').toLowerCase() == 'video') return true;
    // Fallback: check raw URL extension (NOT the full URL)
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.m3u8') ||
        lower.contains('/video/');
  }




  bool _isImagePost(Post p) {
    final url = _getFullImageUrl(p.mediaUrl).toLowerCase();

    return url.contains('.jpg') ||
        url.contains('.jpeg') ||
        url.contains('.png') ||
        url.contains('.gif') ||
        url.contains('.webp');
  }


  /// Fallback: if media exists and not recognized as video, treat as image
  bool _isMediaButUnknown(Post p) {
    final url = (p.mediaUrl ?? '').trim();
    return url.isNotEmpty && !_isVideoPost(p) && !_isImagePost(p);
  }

  List<Post> _activePostsOnly(List<Post> input) {
    // remove pending; keep active/approved
    return input.where((p) => !_isPending(p) && _isActive(p)).toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('خطأ')),
        body: const Center(child: Text('لم يتم العثور على المستخدم')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with Cover Photo and Profile Photo
            _buildHeader(),

            // Profile Header (Name, Stats)
            _buildProfileHeader(),

            const SizedBox(height: 20),

            // Action Buttons (only if not viewing own profile)
            if (_currentUserId != widget.userId)
              _buildActionButtons(),

            const SizedBox(height: 24),

            // Stats Cards
            _buildStatsCards(),

            const SizedBox(height: 24),

            // Personal Info Card
            _buildPersonalInfoCard(),

            const SizedBox(height: 24),

            // Bio Card
            if (_user!.bio != null && _user!.bio!.isNotEmpty)
              _buildBioCard(),

            const SizedBox(height: 24),

            // Tabs (Posts, Videos, Photos)
            _buildTabs(),

            const SizedBox(height: 16),

            // Tab Content - Direct rendering based on selected tab
// Tab Content
            _buildTabContent(),

            const SizedBox(height: 16),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 90),
          ],
        ),

      ),
    );
  }

  // ==================== HEADER ====================
  Widget _buildHeader() {
    final coverUrl = _getFullImageUrl(_user!.coverPhotoUrl);
    final profileUrl = _getFullImageUrl(_user!.profilePhotoUrl);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Cover Photo
        Container(
          height: 200,
          width: double.infinity,
            child: coverUrl.isNotEmpty
                ? GestureDetector(
              onTap: () => _openImageFullScreen(coverUrl, heroTag: 'cover_${widget.userId}'),
              child: Hero(
                tag: 'cover_${widget.userId}',
                child: Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                    ),
                  ),
                ),
              ),
            )
          : Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
      ),


        ),

        // Gradient Overlay (DO NOT block taps)
        IgnorePointer(
          ignoring: true,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),


        // Back Button
        Positioned(
          top: 40,
          left: 8,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),

        // Share Button
        Positioned(
          top: 40,
          right: 56,
          child: IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _shareProfile,
          ),
        ),

        // More Button
        Positioned(
          top: 40,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              // TODO: Show options menu
            },
          ),
        ),

        // Profile Photo - positioned at bottom of cover
        Positioned(
          bottom: -60,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: GestureDetector(
                onTap: () => _openImageFullScreen(profileUrl, heroTag: 'profile_${widget.userId}'),
                child: Hero(
                  tag: 'profile_${widget.userId}',
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: AppColors.greyLight,
                    backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                    child: profileUrl.isEmpty
                        ? const Icon(Icons.person, size: 60, color: AppColors.grey)
                        : null,
                  ),
                ),
              ),

            ),
          ),
        ),
      ],
    );
  }

  // ==================== PROFILE HEADER ====================
  Widget _buildProfileHeader() {
    final profileUrl = _getFullImageUrl(_user!.profilePhotoUrl);

    return Padding(
      padding: const EdgeInsets.only(top: 70),
      child: Column(
        children: [
          // Player Name
          Text(
            _user!.name,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 12),

          // Position & Country
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_user!.position != null) ...[
                const Icon(Icons.sports_soccer, size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  AppLocalizations.of(context)?.tr(PositionTranslator.toTranslationKey(_user!.position)) ?? _user!.position!,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (_user!.position != null && _user!.country != null) ...[
                const SizedBox(width: 12),
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (_user!.country != null)
                Text(
                  AppLocalizations.of(context)?.tr(_user!.country!.toLowerCase().replaceAll(' ', '_')) ?? _user!.country!,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== ACTION BUTTONS ====================
  Widget _buildActionButtons() {
    final loc = AppLocalizations.of(context);

    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            // Main action buttons row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _toggleFollow,
                    icon: Icon(
                      _isFollowing ? Icons.check : Icons.add,
                      color: Colors.white,
                    ),
                    label: Text(
                      _isFollowing ? (loc?.tr('following') ?? 'متابع') : (loc?.tr('follow') ?? 'متابعة'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isFollowing ? AppColors.grey : AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _startChat,
                    icon: const Icon(Icons.message_outlined, color: AppColors.primary),
                    label: Text(
                      loc?.tr('message') ?? 'رسالة',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.primary, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Report and Block buttons row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showReportUserSheet,
                    icon: const Icon(Icons.flag_outlined, color: Colors.orange, size: 20),
                    label: Text(
                      loc?.tr('report') ?? 'الإبلاغ',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Colors.orange, width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showBlockUserDialog,
                    icon: const Icon(Icons.block, color: Colors.red, size: 20),
                    label: Text(
                      loc?.tr('block') ?? 'حظر',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Colors.red, width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        )
    );
  }

  void _showReportUserSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReportContentSheet(
        contentId: widget.userId,
        contentType: 'user',
        contentTitle: _user?.name ?? '',
      ),
    );
  }

  void _showBlockUserDialog() {
    showDialog(
      context: context,
      builder: (context) => BlockUserDialog(
        userId: widget.userId,
        userName: _user?.name ?? '',
        onBlocked: () {
          // Navigate back after blocking
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)?.tr('user_blocked') ?? 'تم حظر المستخدم'),
              backgroundColor: AppColors.success,
            ),
          );
        },
      ),
    );
  }

  // ==================== STATS CARDS ====================
  Widget _buildStatsCards() {
    final activePosts = _activePostsOnly(_posts); // ✅ FIX #2: count only active

    return Transform.translate(
      offset: Offset(0, _currentUserId != widget.userId ? -30 : 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _buildStatCard(
              icon: Icons.people,
              value: '${_user?.followersCount ?? 0}',
              label: 'المتابعون',
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              icon: Icons.star,
              value: '0',
              label: 'التقييم',
              color: AppColors.accentGold,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              icon: Icons.article,
              value: '${activePosts.length}', // ✅ instead of _posts.length
              label: 'المنشورات',
              color: AppColors.accentOrange,
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== PERSONAL INFO CARD ====================
  Widget _buildPersonalInfoCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primary, size: 24),
                SizedBox(width: 8),
                Text(
                  'المعلومات الشخصية',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            /*if (_user!.age != null)
              _buildInfoRow(Icons.cake, 'العمر', '${_user!.age} سنة'),
            if (_user!.age != null) const SizedBox(height: 12),*/
            if (_user!.height != null)
              _buildInfoRow(Icons.height, 'الطول', '${_user!.height} سم'),
            if (_user!.height != null) const SizedBox(height: 12),
            if (_user!.weight != null)
              _buildInfoRow(Icons.fitness_center, 'الوزن', '${_user!.weight} كجم'),
            if (_user!.weight != null) const SizedBox(height: 12),
            if (_user!.currentClub != null && _user!.currentClub!.isNotEmpty)
              _buildInfoRow(Icons.sports_soccer, 'النادي', _user!.currentClub!),
            if (_user!.currentClub != null && _user!.currentClub!.isNotEmpty) const SizedBox(height: 12),
            if (_user!.email.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(Icons.email, 'البريد', _user!.email),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.grey),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ==================== BIO CARD ====================
  Widget _buildBioCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.description, color: AppColors.primary, size: 24),
                SizedBox(width: 8),
                Text(
                  'نبذة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _user!.bio!,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isTextPost(Post p) {
    return (p.mediaUrl ?? '').trim().isEmpty;
  }

  // ==================== TABS ====================
  Widget _buildTabs() {
    final active = _activePostsOnly(_posts);

    final totalCount = active.length;
    final postsCount = active.where(_isTextPost).length;
    final videosCount = active.where(_isVideoPost).length;
    final photosCount = active.where((p) => _isImagePost(p) || _isMediaButUnknown(p)).length;

    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.grey,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        onTap: (_) => setState(() {}),
        tabs: [
          Tab(text: 'الكل ($totalCount)'),
          Tab(text: 'صورة ($photosCount)'),
          Tab(text: 'فيديو ($videosCount)'),
          Tab(text: 'منشور ($postsCount)'),


        ],
      ),
    );
  }


  // ==================== TAB CONTENT ====================
  Widget _buildTabContent() {
    final active = _activePostsOnly(_posts);

    switch (_tabController.index) {
      case 0: // All
        return _buildPostsList(active);

      case 1: // Text posts
        final images = active.where((p) => _isImagePost(p) || _isMediaButUnknown(p)).toList();
        return _buildPhotosGrid(images);

      case 2: // Videos
        final videos = active.where(_isVideoPost).toList();
        return _buildVideosGrid(videos);

      case 3: // Images
        final textPosts = active.where(_isTextPost).toList();
        return _buildPostsList(textPosts);

      default:
        return _buildPostsList(active);
    }
  }


  Widget _buildPostsList(List<Post> list) {
    if (list.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('لا توجد عناصر'),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final post = list[index];
        return PostCard(
          key: ValueKey('profile_post_${post.id}'),
          post: post,
          onReaction: _handleReaction,
          onDelete: _handleDeletePost,
          currentUserId: _currentUserId,
          onCommentAdded: _loadUserPosts,
          viewScope: 'profile_${widget.userId}',
          enableViewIncrement: false,
          viewedCache: _viewedInProfile,
          onViewsUpdated: _updatePostViews,
          onOpenImage: (url, heroTag) => _openImageFullScreen(url, heroTag: heroTag),
          onOpenVideo: (url) {
            final fullUrl = ApiService.toAbsoluteUrl(url);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FullScreenVideoPage(videoUrl: fullUrl),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVideosGrid(List<Post> videos) {
    if (videos.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('لا توجد فيديوهات'),
        ),
      );
    }

    // For now, just show them as PostCards (so you don’t need a video widget yet)
    // Later we can convert this to a real video grid with a player.
    return _buildPostsList(videos);
  }

  Widget _buildPhotosGrid(List<Post> photos) {
    if (photos.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('لا توجد صور'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: photos.map((photo) {
          final photoUrl = _getFullImageUrl(photo.mediaUrl);
          final screenWidth = MediaQuery.of(context).size.width;
          final itemWidth = (screenWidth - 48) / 3;

          return SizedBox(
            width: itemWidth,
            height: itemWidth,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: GestureDetector(
                onTap: () => _openImageFullScreen(photoUrl, heroTag: 'post_${photo.id}'),
                child: Hero(
                  tag: 'post_${photo.id}',
                  child: Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.greyLight,
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                ),
              ),
            ),
          );

        }).toList(),
      ),
    );
  }

  // ==================== TAB VIEWS ====================

}
