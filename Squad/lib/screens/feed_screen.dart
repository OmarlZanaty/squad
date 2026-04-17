import 'package:flutter/material.dart';
import 'package:squad/utils/app_colors.dart';
import 'package:squad/services/api_service.dart';
import 'package:squad/services/auth_service.dart';
import 'package:squad/models/post.dart';
import 'package:squad/widgets/post_card.dart';
import 'package:squad/widgets/app_bottom_bar.dart';
import 'package:squad/widgets/app_top_bar.dart';
import 'package:squad/screens/search_screen.dart';
import 'package:squad/utils/app_localizations.dart';
import 'package:squad/screens/player_profile_screen.dart';

import '../widgets/double_back_exit.dart';
import 'full_screen_video_page.dart';
import 'fullscreen_image_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Post> _posts = [];
  bool _isLoading = false;
  String _filterType = 'all';
  String? _token;
  String? _errorMessage;
  int? _currentUserId;
  DateTime? _lastCreatedAt;
  bool _isFirstLoad = true;
  final ScrollController _scrollController = ScrollController();
  bool _isFetchingMore = false;
  bool _hasMore = true;

  Future<void> _loadMorePosts() async {
    if (_token == null || _isFetchingMore) return;

    _isFetchingMore = true;

    try {
      final result = await ApiService.getPosts(
        _token!,
        role: _filterType == 'all' ? null : _filterType,
        lastCreatedAt: _lastCreatedAt?.toIso8601String(),
      );

      if (result is List && result.isNotEmpty) {
        final List<Post> newPosts = result
            .map((e) => Post.fromJson(e))
            .toList();

        setState(() {
          _posts.addAll(newPosts); // ✅ IMPORTANT
        });

        _lastCreatedAt = newPosts.last.createdAt;
      } else {
        _hasMore = false;
      }
    } catch (e) {
      debugPrint("Load more error: $e");
    }

    _isFetchingMore = false;
  }



  @override
  void initState() {
    super.initState();
    _loadToken();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 300 &&
          !_isFetchingMore &&
          _hasMore) {
        _loadMorePosts();
      }
    });

  }

  void _openPlayerProfile(int userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerProfileScreen(userId: userId),
      ),
    );
  }

  Future<void> _loadToken() async {
    _token = await AuthService.getToken();
    _currentUserId = await AuthService.getUserId();
    if (_token != null) {
      _loadPosts();
    } else {
      setState(() {
        _errorMessage = 'No authentication token found';
      });
    }
  }

  String _getFullMediaUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    final u = url.trim();
    final full = u.startsWith('http') ? u : 'http://187.124.37.68:3000$u';
    return Uri.encodeFull(full); // important for spaces/arabic chars
  }


  Future<void> _loadPosts() async {
    if (_token == null) {
      setState(() {
        _errorMessage = 'Cannot load posts - not authenticated';
      });
      return;
    }

    // ✅ ADD THESE 3 LINES — reset pagination on every full reload
    _lastCreatedAt = null;
    _isFirstLoad = true;
    _hasMore = true;


    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.getPosts(
        _token!,
        role: _filterType == 'all' ? null : _filterType,
        lastCreatedAt: null, // ✅ always null on fresh load
      );

      if (result is List) {
        final List<Post> posts = [];
        try {
          for (var item in result as List) {
            final post = Post.fromJson(item as Map<String, dynamic>);

            final isOwner = _currentUserId != null && _currentUserId == post.userId;
            final isPending = post.status.toLowerCase() == 'pending';
            final isHidden = post.isHidden;

            if (isOwner || (!isPending && !isHidden)) {
              posts.add(post);
            }
          }

// ✅ FEED ORDER FIX (ignore pinned completely)
          posts.sort((a, b) {
            final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bd.compareTo(ad);
          });

          // ✅ ADD THIS BLOCK HERE
          if (posts.isNotEmpty) {
            _lastCreatedAt = posts.last.createdAt;
            _isFirstLoad = false;
          }

          setState(() {
            _posts = posts;
            _isLoading = false;
            _errorMessage = null;
          });

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


  void _updatePostViews(int postId, int newViews) {
    final i = _posts.indexWhere((p) => p.id == postId);
    if (i != -1) {
      _posts[i] = _posts[i].copyWith(views: newViews);
    }
  }

  Future<void> _handleReaction(int postId, String reactionType) async {
    if (_token == null) return;

    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = _posts[index];

    // 🔥 OPTIMISTIC UPDATE
    setState(() {
      _posts[index] = post.copyWith(
        userReaction: reactionType,
        likeCount: reactionType == 'like' ? post.likeCount + 1 : post.likeCount,
        loveCount: reactionType == 'love' ? post.loveCount + 1 : post.loveCount,
        talentCount: reactionType == 'talent' ? post.talentCount + 1 : post.talentCount,
        amazingCount: reactionType == 'amazing' ? post.amazingCount + 1 : post.amazingCount,
      );
    });

    try {
      await ApiService.reactToPost(
        token: _token!,
        postId: postId,
        reactionType: reactionType,
      );
    } catch (e) {
      // rollback if failed
      await _loadPosts();
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
              backgroundColor: Colors.green,
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

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return DoubleBackExit(
      message: AppLocalizations.of(context)?.tr('press_back_again_exit')
          ?? 'Press back again to exit',
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: const AppTopBar(),
        body: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _lastCreatedAt = null;   // ✅ reset before reload
                  _isFirstLoad = true;
                  await _loadPosts();
                },
                child: _buildBody(),
              ),
            ),
          ],
        ),
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
      controller: _scrollController,
      addRepaintBoundaries: true,
      addAutomaticKeepAlives: true,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewPadding.bottom + 80,
      ),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];

        return PostCard(
          key: ValueKey(post.id),
          post: post,
          onReaction: _handleReaction,
          onDelete: _handleDeletePost,
          currentUserId: _currentUserId,
          onCommentAdded: _loadPosts,
          onUserTap: _openPlayerProfile,
          onViewsUpdated: _updatePostViews,
          onOpenImage: (url, heroTag) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FullscreenImageScreen(imageUrl: url, heroTag: heroTag),
              ),
            );
          },
          onOpenVideo: (url) {
            final full = _getFullMediaUrl(url);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FullScreenVideoPage(videoUrl: full),
              ),
            );
          },
        );
      },
    );

  }
}
