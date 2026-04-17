import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../utils/app_colors.dart';
import '../utils/app_localizations.dart';
import 'chat_conversation_screen.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<User> _users = [];
  List<User> _filteredUsers = [];
  bool _isLoading = false;
  bool _isSearching = false;

  String _translatePosition(String? position) {
    if (position == null || position.isEmpty) return '';
    final Map<String, String> positionToKey = {
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
    String? key = positionToKey[position];
    if (key != null) {
      return AppLocalizations.of(context)?.tr(key) ?? position;
    }
    return position;
  }

  String _translateCountry(String? country) {
    if (country == null || country.isEmpty) return '';
    final loc = AppLocalizations.of(context);
    // Map country names to localization keys
    final Map<String, String> countryToKey = {
      'Egypt': 'egypt',
      'Saudi Arabia': 'saudi_arabia',
      'UAE': 'uae',
      'Kuwait': 'kuwait',
      'Qatar': 'qatar',
    };
    String? key = countryToKey[country];
    if (key != null) {
      return loc?.tr(key) ?? country;
    }
    return country;
  }

  String _translateUserType(String? userType) {
    if (userType == null || userType.isEmpty) return '';
    final Map<String, String> userTypeToKey = {
      'player': 'player',
      'scout': 'scout',
      'guest': 'guest',
    };
    String? key = userTypeToKey[userType.toLowerCase()];
    if (key != null) {
      return AppLocalizations.of(context)?.tr(key) ?? userType;
    }
    return userType;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {}); // Rebuild to show/hide clear button
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _filterUsers(String query) async {
    print('🔍 User search query: "$query"');

    if (query.isEmpty) {
      setState(() {
        _filteredUsers = [];
        _users = [];
        _isSearching = false;
      });
      print('✅ Cleared search');
      return;
    }

    if (query.length < 2) {
      print('⏳ Waiting for at least 2 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _isSearching = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('Not authenticated');
      }

      print('🔍 Searching API for: $query');
      final users = await ApiService.searchUsers(token: token, query: query);

      setState(() {
        _users = users;
        _filteredUsers = users;
        _isLoading = false;
      });
      print('✅ Found ${_users.length} users');
    } catch (e) {
      print('💥 Search error: $e');
      setState(() {
        _isLoading = false;
        _users = [];
        _filteredUsers = [];
      });
    }
  }

  Future<void> _startChatWithUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('Not authenticated');
      }

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      // Start chat
      final response = await ApiService.startChat(
        token: token,
        otherUserId: user.id,
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (response['chat_id'] != null) {

        // Navigate to conversation
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ChatConversationScreen(
                chatId: response['chat_id'],
                otherUserId: user.id, // ✅ CORRECT
                otherUserName: user.name,
                otherUserPhoto: user.profilePhotoUrl,
              ),
            ),
          );
        }
      } else {
        // Show error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.tr('failed_to_start_chat'))),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if open
      if (mounted) Navigator.pop(context);

      print('Error starting chat: $e');
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
          AppLocalizations.of(context)!.tr('start_new_chat'),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(isDark),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                ? _buildEmptyState(isDark)
                : _buildUserList(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.tr('search_users'),
          hintStyle: TextStyle(color: Colors.grey),
          border: InputBorder.none,
          icon: Icon(Icons.search, color: Colors.grey),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: Colors.grey),
            onPressed: () {
              setState(() {
                _searchController.clear();
              });
              _filterUsers('');
            },
          )
              : null,
        ),
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        onChanged: _filterUsers,
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isSearching ? Icons.search_off : Icons.people_outline,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            _isSearching
                ? AppLocalizations.of(context)!.tr('no_users_found')
                : AppLocalizations.of(context)!.tr('search_for_users'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _isSearching
                ? AppLocalizations.of(context)!.tr('try_different_search')
                : AppLocalizations.of(context)!.tr('type_2_chars'),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList(bool isDark) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return _buildUserItem(user, isDark);
      },
    );
  }

  Widget _buildUserItem(User user, bool isDark) {
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
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: user.type.toLowerCase() == 'player'
                    ? AppColors.primary.withOpacity(0.2)
                    : AppColors.secondary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _translateUserType(user.type).toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: user.type.toLowerCase() == 'player' ? AppColors.primary : AppColors.secondary,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user.email != null && user.email!.isNotEmpty)
              Text(
                user.email!,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            if ((user.country != null && user.country!.isNotEmpty) ||
                (user.position != null && user.position!.isNotEmpty))
              SizedBox(height: 4),
            if ((user.country != null && user.country!.isNotEmpty) ||
                (user.position != null && user.position!.isNotEmpty))
              Text(
                [_translateCountry(user.country), _translatePosition(user.position)]
                    .where((s) => s.isNotEmpty)
                    .join(' • '),
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _startChatWithUser(user),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: Text(AppLocalizations.of(context)!.tr('chat'), style: TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}
