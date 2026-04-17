import 'package:flutter/material.dart';
import 'package:squad/utils/app_colors.dart';
import 'package:squad/services/api_service.dart';
import 'package:squad/services/auth_service.dart';
import 'package:squad/models/user.dart';
import 'package:squad/screens/player_profile_screen.dart';
import 'package:squad/screens/chat_conversation_screen.dart';
import '../utils/app_localizations.dart';
import 'package:squad/utils/position_translator.dart';
enum SearchMode { profile, chat }

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  final SearchMode mode;
  final List<User>? initialPlayers; // ✅ passed from Home (filtered list)

  const SearchScreen({
    super.key,
    this.initialQuery,
    this.mode = SearchMode.profile,
    this.initialPlayers,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<User> _searchResults = [];
  bool _isLoading = false;
  String? _token;

  bool get _isLocalMode => widget.initialPlayers != null;

  @override
  void initState() {
    super.initState();

    // Put initial query in the field
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
    }

    // ✅ If Home passed list => local filtering only
    if (_isLocalMode) {
      _filterLocal(_searchController.text);
      _searchController.addListener(() {
        _filterLocal(_searchController.text);
      });
      return;
    }

    if (_isLocalMode) {
      debugPrint('SearchScreen local mode players=${widget.initialPlayers?.length}');
      _filterLocal(_searchController.text);
      _searchController.addListener(() {
        _filterLocal(_searchController.text);
      });
      return;
    }

    // ✅ Otherwise use API search
    _loadToken();
  }

  Future<void> _loadToken() async {
    _token = await AuthService.getToken();

    // If screen opened with initial query, auto search
    if (widget.initialQuery != null && _token != null) {
      _performSearch(widget.initialQuery!);
    }
  }

  void _filterLocal(String query) {
    final q = query.toLowerCase().trim();
    final base = widget.initialPlayers ?? const <User>[];

    setState(() {
      // Proposed fix for _filterLocal
      _searchResults = base.where((u) {
        // Ensure user is a 'player' and 'active' in local mode as well
        if ((u.type ?? '').toLowerCase() != 'player') return false;
        if ((u.status ?? '').toLowerCase() != 'active') return false;

        if (q.isEmpty) return true;
        final name = u.name.toLowerCase();
        final pos = (u.position ?? '').toLowerCase();
        final country = (u.country ?? '').toLowerCase();
        return name.contains(q) || pos.contains(q) || country.contains(q);
      }).toList();
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty || _token == null) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final results = await ApiService.searchUsers(
        token: _token!,
        query: query.trim(),
      );

      final playerResults = results
          .where((user) => (user.type ?? '').toLowerCase() == 'player')
          .toList();

      setState(() {
        _searchResults = playerResults;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);

      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${loc?.tr('search_error') ?? 'Search Error'}: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _getFullImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return 'http://187.124.37.68:3000$url';
  }

  Future<void> _startChatWithUser(User user) async {
    final profileUrl = _getFullImageUrl(user.profilePhotoUrl);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ChatConversationScreen(
          otherUserId: user.id,
          otherUserName: user.name,
          otherUserPhoto: profileUrl.isNotEmpty ? profileUrl : null,
        ),
      ),
    );
  }

  void _handleUserTap(User user) {
    if (widget.mode == SearchMode.chat) {
      _startChatWithUser(user);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerProfileScreen(userId: user.id),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    String hintText() {
      if (widget.mode == SearchMode.chat) {
        return loc?.tr('search_users') ?? 'Search for users...';
      }
      return loc?.tr('search_players') ?? 'Search for players...';
    }

    void runSearch() {
      final q = _searchController.text;
      if (_isLocalMode) {
        _filterLocal(q);
      } else {
        _performSearch(q);
      }
    }

    return Scaffold(
      backgroundColor:
      isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: widget.initialQuery == null,
          textDirection: TextDirection.rtl,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: hintText(),
            border: InputBorder.none,
            hintStyle: const TextStyle(color: AppColors.grey),
          ),
          onSubmitted: (_) => runSearch(),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: AppColors.grey),
              onPressed: () {
                _searchController.clear();
                if (_isLocalMode) {
                  _filterLocal(''); // ✅ show all passed players again
                } else {
                  setState(() => _searchResults = []);
                }
              },

            ),
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.primary),
            onPressed: runSearch,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // ✅ Local mode: show the list even if the search text is empty
    if (_isLocalMode) {
      if (_searchResults.isEmpty) {
        return _buildNoResults(); // or create a special "No players" UI
      }
      return _buildSearchResults();
    }

    // ✅ API mode: keep old behavior (empty text => empty state)
    if (_searchController.text.isEmpty) {
      return _buildEmptyState();
    }

    if (_searchResults.isEmpty) {
      return _buildNoResults();
    }

    return _buildSearchResults();
  }


  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    final title = widget.mode == SearchMode.chat
        ? (loc?.tr('search_to_chat') ?? 'Search to start a chat')
        : (loc?.tr('search_players') ?? 'Search for players...');

    final subtitle = widget.mode == SearchMode.chat
        ? (loc?.tr('type_name_to_chat') ?? 'Type a username to start a chat')
        : (loc?.tr('type_name_to_search') ??
        'Type a player name or position to search');

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.mode == SearchMode.chat
                ? Icons.chat_bubble_outline
                : Icons.search,
            size: 100,
            color: AppColors.grey.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 14, color: AppColors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 100,
            color: AppColors.grey.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            loc?.tr('no_results') ?? 'No Results',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${loc?.tr('no_results_for') ?? 'We couldn\'t find any results for'} "${_searchController.text}"',
            style: const TextStyle(fontSize: 14, color: AppColors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildUserCard(User user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileUrl = _getFullImageUrl(user.profilePhotoUrl);
    final loc = AppLocalizations.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? AppColors.cardDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _handleUserTap(user),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.greyLight,
                backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                child: profileUrl.isEmpty
                    ? const Icon(Icons.person, size: 30, color: AppColors.grey)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (user.position != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryVeryLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              // 🔁 REPLACE THIS LINE ONLY
                              loc?.tr(PositionTranslator.toTranslationKey(user.position)) ?? (user.position ?? ''),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (user.country != null)
                          Text(
                            user.country!,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.grey[400] : AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.mode == SearchMode.chat)
                Icon(
                  Icons.chat_bubble_outline,
                  color: isDark ? AppColors.darkAccent : AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}


