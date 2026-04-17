import 'dart:async';

import 'package:flutter/material.dart';
import 'package:squad_player/utils/app_colors.dart';
import 'package:squad_player/services/api_service.dart';
import 'package:squad_player/services/auth_service.dart';
import 'package:squad_player/models/post.dart';
import 'package:squad_player/widgets/post_card.dart';
import 'package:squad_player/utils/app_localizations.dart';
import 'package:squad_player/screens/create_post_screen.dart';
import 'package:squad_player/screens/main_screen.dart';
import 'package:squad_player/screens/edit_post_screen.dart';
import 'package:squad_player/screens/notification_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, this.scrollToPostId}); // ✅ Ensure this is here

  final int? scrollToPostId; // ✅ Ensure this is here


  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Post> _posts = [];
  bool _isLoading = false;
  String? _token;
  String? _errorMessage;
  int? _currentUserId;
  int _unreadNotifications = 0;
  Timer? _refreshTimer;
  final ScrollController _scrollController = ScrollController(); // ✅ Add this
  final Map<int, GlobalKey> _postKeys = {}; // ✅ Add this



  @override
  void initState() {
    super.initState();
    _loadToken();

    // ✅ Check for initial scroll request
    if (widget.scrollToPostId != null) {
      _scrollToPost(widget.scrollToPostId!);
    }

  }

  @override
  void didUpdateWidget(FeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ✅ Check if a new scroll request came in
    if (widget.scrollToPostId != null && widget.scrollToPostId != oldWidget.scrollToPostId) {
      _scrollToPost(widget.scrollToPostId!);
    }
  }

  void _scrollToPost(int postId) {
    // Wait for the list to be rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _postKeys[postId];
      if (key != null && key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      } else {
        // Fallback: If the item is not in the viewport, scroll to an estimated position
        final index = _posts.indexWhere((p) => p.id == postId);
        if (index != -1) {
          _scrollController.animateTo(
            index * 400.0, // Estimated height of a PostCard
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }


  Future<void> _loadToken() async {
    _token = await AuthService.getToken();
    _currentUserId = await AuthService.getUserId();
    if (_token != null) {
      _loadPosts();
      _loadUnreadNotifications();
    } else {
      setState(() {
        _errorMessage = 'No authentication token found';
      });
    }
  }

  void _startAutoRefreshIfNeeded() {
    final hasPending = _posts.any((p) => p.status == 'pending');

    if (hasPending && _refreshTimer == null) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
        if (!mounted) return;

        await _loadPosts();

        // Stop when no pending posts left
        final stillPending = _posts.any((p) => p.status == 'pending');
        if (!stillPending) {
          timer.cancel();
          _refreshTimer = null;
        }
      });
    }
  }

  Future<void> _loadUnreadNotifications() async {
    if (_token == null) return;
    try {
      final response = await ApiService.getUnreadNotificationCount(_token!);
      if (response['success'] == true) {
        setState(() {
          _unreadNotifications = response['count'] ?? 0;
        });
      }
    } catch (e) {
      print('Error loading unread notifications: $e');
    }
  }

  Future<void> _loadPosts() async {
    if (_token == null || _currentUserId == null) {
      setState(() {
        _errorMessage = 'Cannot load posts - not authenticated';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;

    });


    try {
      // Load only current user's posts
      final result = await ApiService.getUserPosts(
        token: _token!,
        userId: _currentUserId!,
      );

      if (result is List) {
        final List<Post> posts = [];
        try {
          for (var item in result as List) {
            posts.add(Post.fromJson(item as Map<String, dynamic>));
          }
          // ✅ FIXED: Sort posts - pinned first, then by ID descending
          posts.sort((a, b) {
            if (a.isPinned && !b.isPinned) return -1;
            if (!a.isPinned && b.isPinned) return 1;
            return b.id.compareTo(a.id);
          });
          setState(() {
            _posts = posts;
            _isLoading = false;
            _errorMessage = null;
          });
          _startAutoRefreshIfNeeded();
        } catch (parseError) {
          setState(() {
            _errorMessage = 'Error parsing posts: $parseError\nFirst item: ${result.isNotEmpty ? result[0] : "empty"}';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Unexpected response format: ${result.runtimeType}\nData: $result';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load posts: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleReaction(int postId, String reactionType) async {
    if (_token == null) return;

    final postIndex = _posts.indexWhere((p) => p.id == postId);
    if (postIndex == -1) return;

    final post = _posts[postIndex];
    final originalReaction = post.userReaction;
    final originalCounts = {
      'like': post.likeCount,
      'love': post.loveCount,
      'talent': post.talentCount,
      'amazing': post.amazingCount,
    };

    // Optimistic UI update
    if (post.userReaction == reactionType) {
      // Un-react
      post.userReaction = null;
      post.decrementReaction(reactionType);
    } else {
      // Change or add reaction
      if (post.userReaction != null) {
        post.decrementReaction(post.userReaction!);
      }
      post.userReaction = reactionType;
      post.incrementReaction(reactionType);
    }

    setState(() {
      _posts = [..._posts]; // Create a new list to trigger rebuild
    });

    try {
      await ApiService.reactToPost(
        token: _token!,
        postId: postId,
        reactionType: reactionType,
      );
    } catch (e) {
      // Revert on error
      post.userReaction = originalReaction;
      post.likeCount = originalCounts['like']!;
      post.loveCount = originalCounts['love']!;
      post.talentCount = originalCounts['talent']!;
      post.amazingCount = originalCounts['amazing']!;

      setState(() {
        _posts = [..._posts]; // Create a new list to trigger rebuild
      });

      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc?.tr('error') ?? 'Error'}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleDeletePost(int postId) async {
    if (_token == null) return;

    try {
      final result = await ApiService.deletePost(
        token: _token!,
        postId: postId,
      );

      if (result['message'] != null && result['message'].toString().contains('success')) {
        // Remove post from list
        setState(() {
          _posts.removeWhere((post) => post.id == postId);
        });

        if (mounted) {
          final loc = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc?.tr('post_deleted_successfully') ?? 'Post deleted successfully'),
              backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkAccent : AppColors.primary,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception(result['message'] ?? 'Failed to delete post');
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc?.tr('error_deleting_post') ?? 'Error deleting post'}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleEditPost(int postId) async {
    // Find the post to edit
    final post = _posts.firstWhere((p) => p.id == postId);

    // Navigate to edit screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPostScreen(post: post),
      ),
    );

    // Reload posts if edit was successful
    if (result == true) {
      await _loadPosts();
    }
  }

  void _handlePin(int postId, bool isPinned) {
    setState(() {
      final index = _posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        _posts[index].isPinned = isPinned;
        // Re-sort posts: Pinned first, then by date (assuming original order was by date)
        _posts.sort((a, b) {
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          // If both pinned or both not pinned, keep original order (by ID descending usually)
          return b.id.compareTo(a.id);
        });
      }
    });
  }

  void _handleHide(int postId, bool isHidden) {
    setState(() {
      final index = _posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        _posts[index].isHidden = isHidden;
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.dispose(); // ✅ Add this
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                        final postId = await Navigator.push<int>(
                          context,
                          MaterialPageRoute(builder: (context) => const NotificationScreen()),
                        );

                        _loadUnreadNotifications();

                        if (postId != null && mounted) {
                          // ✅ Find the MainScreen state and tell it to navigate
                          final mainState = context.findAncestorStateOfType<MainScreenState>();
                          if (mainState != null) {
                            mainState.navigateToFeed(postId);
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
                          loc?.tr('app_name') ?? 'SQUAD',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkAccent : AppColors.primary,
                            letterSpacing: 1.5,
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
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(loc?.tr('contact_us_coming_soon') ?? 'Contact us coming soon...')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        child: _buildBody(),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 70),
        child: FloatingActionButton.extended(
          heroTag: 'feed_fab',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CreatePostScreen(),
              ),
            ).then((_) => _loadPosts());
          },
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkAccent : AppColors.primary,
          icon: Icon(Icons.add, color: Colors.white),
          label: Text(loc?.tr('create_post') ?? 'Create Post', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations? loc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Arrow (Left)
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 28, color: AppColors.black),
            onPressed: () => Navigator.pop(context),
          ),

          // Logo (Center)
          Image.asset(
            'assets/images/logo.png',
            height: 50,
          ),

          // Refresh Button (Right)
          IconButton(
            icon: const Icon(Icons.refresh, size: 28, color: AppColors.black),
            onPressed: _loadPosts,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final loc = AppLocalizations.of(context);

    if (_errorMessage != null) {
      return ListView(
        children: [
          Container(
            height: MediaQuery.of(context).size.height - 200,
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 20),
                  Text(
                    loc?.tr('error_loading_posts') ?? 'Error loading posts',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loadPosts,
                    child: Text(loc?.tr('try_again') ?? 'Try Again'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_isLoading && _posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_posts.isEmpty) {
      return ListView(
        children: [
          Container(
            height: MediaQuery.of(context).size.height - 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inbox, size: 80, color: Colors.grey),
                  const SizedBox(height: 20),
                  Text(
                    loc?.tr('no_posts_yet') ?? 'No posts yet',
                    style: const TextStyle(fontSize: 20, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    loc?.tr('be_first_to_post') ?? 'Be the first to post',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController, // ✅ Attach the controller
      padding: const EdgeInsets.only(bottom: 140),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];
        // ✅ Assign a unique key to each PostCard
        final key = _postKeys.putIfAbsent(post.id, () => GlobalKey());

        return PostCard(
          key: key, // ✅ Pass the key here
          post: post,
          onReaction: _handleReaction,
          onDelete: _handleDeletePost,
          onEdit: _handleEditPost,
          onPin: _handlePin,
          onHide: _handleHide,
          currentUserId: _currentUserId,
        );
      },
    );

  }
}
