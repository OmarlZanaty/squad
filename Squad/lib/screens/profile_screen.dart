import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../utils/app_colors.dart';
import '../models/user.dart';
import '../widgets/app_bottom_bar.dart';
import '../utils/app_localizations.dart';
import 'player_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedType = 'player';

  File? _profileImage;
  File? _coverImage;
  User? _user;
  List<User> _followingList = [];
  bool _isLoadingFollowing = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadFollowingList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userId = prefs.getInt('user_id');

      final response = await http.get(
        Uri.parse('http://187.124.37.68:3000/api/users/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _user = User.fromJson(data);

        setState(() {
          _nameController.text = _user!.name;
          _emailController.text = _user!.email;
          _phoneController.text = _user!.phone ?? '';
          _selectedType = _user!.type;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load user data');
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickImage(bool isProfile) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        if (isProfile) {
          _profileImage = File(pickedFile.path);
        } else {
          _coverImage = File(pickedFile.path);
        }
      });
    }
  }

  void _enableEditing() {
    setState(() => _isEditing = true);
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('http://187.124.37.68:3000/api/auth/update-profile'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      // Add text fields
      request.fields['name'] = _nameController.text;
      request.fields['email'] = _emailController.text;
      request.fields['type'] = _selectedType;

      // Add images if selected
      if (_profileImage != null) {
        request.files.add(await http.MultipartFile.fromPath('profile_photo', _profileImage!.path));
      }

      if (_coverImage != null) {
        request.files.add(await http.MultipartFile.fromPath('cover_photo', _coverImage!.path));
      }

      final response = await request.send().timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text(AppLocalizations.of(context)?.tr('profile_updated_successfully') ?? 'Profile updated successfully'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            _isEditing = false;
            _profileImage = null;
            _coverImage = null;
          });
          await _loadUserData(); // Reload to get updated URLs
        }
      } else {
        throw Exception('Failed to update profile');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatJoinDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';

    try {
      final date = DateTime.parse(dateStr);

      // dd/MM/yyyy  (example: 02/02/2026)
      return DateFormat('dd/MM/yyyy').format(date.toLocal());
    } catch (e) {
      return '-';
    }
  }


  Future<void> _loadFollowingList() async {
    setState(() => _isLoadingFollowing = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userId = prefs.getInt('user_id');

      final response = await http.get(
        Uri.parse('http://187.124.37.68:3000/api/users/$userId/following'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _followingList = data.map((json) => User.fromJson(json)).toList();
          _isLoadingFollowing = false;
        });
      } else {
        throw Exception('Failed to load following list');
      }
    } catch (e) {
      print('Error loading following list: $e');
      setState(() => _isLoadingFollowing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.tr('profile') ?? 'Profile'),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving ? null : (_isEditing ? _saveProfile : _enableEditing),
              child: _isSaving
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                _isEditing ? (AppLocalizations.of(context)?.tr('save') ?? 'Save') : (AppLocalizations.of(context)?.tr('edit') ?? 'Edit'),
                style: TextStyle(
                  color: isDark ? AppColors.darkAccent : AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadUserData,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCoverPhotoSection(isDark),
              _buildProfilePhotoSection(isDark),
              SizedBox(height: 20),
              _buildInfoSection(isDark),
              SizedBox(height: 24),
              _buildFollowingSection(isDark),
              SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPhotoSection(bool isDark) {
    return Stack(
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.grey[300],
          ),
          child: _coverImage != null
              ? Image.file(_coverImage!, fit: BoxFit.cover)
              : (_user?.coverPhotoUrl != null
              ? Image.network(
            (_user!.coverPhotoUrl?.startsWith('http') ?? false)
                ? _user!.coverPhotoUrl!
                : 'http://187.124.37.68:3000${_user!.coverPhotoUrl}',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(),
          )
              : Center(
            child: Icon(Icons.photo_camera, size: 50, color: Colors.grey),
          )),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.small(
            heroTag: 'profile_fab',
            onPressed: _isEditing ? () => _pickImage(false) : null,
            backgroundColor: _isEditing ? (isDark ? AppColors.darkAccent : AppColors.primary) : Colors.grey,
            child: Icon(Icons.camera_alt, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildProfilePhotoSection(bool isDark) {
    return Transform.translate(
      offset: Offset(0, -50),
      child: Center(
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                  width: 5,
                ),
              ),
              child: CircleAvatar(
                radius: 60,
                backgroundColor: AppColors.greyLight,
                backgroundImage: _profileImage != null
                    ? FileImage(_profileImage!)
                    : (_user?.profilePhotoUrl != null
                    ? NetworkImage((_user!.profilePhotoUrl?.startsWith('http') ?? false)
                    ? _user!.profilePhotoUrl!
                    : 'http://187.124.37.68:3000${_user!.profilePhotoUrl}')
                    : null) as ImageProvider?,
                child: _profileImage == null && _user?.profilePhotoUrl == null
                    ? Icon(Icons.person, size: 60, color: isDark ? Colors.grey[600] : AppColors.grey)
                    : null,
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: _isEditing ? () => _pickImage(true) : null,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isEditing ? AppColors.primary : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                      width: 3,
                    ),
                  ),
                  child: Icon(Icons.camera_alt, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(bool isDark) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(AppLocalizations.of(context)?.tr('full_name') ?? 'Name', _nameController, Icons.person, isDark),
          SizedBox(height: 16),
          _buildTypeDropdown(isDark),
          SizedBox(height: 16),
          _buildInfoCard(
            AppLocalizations.of(context)?.tr('member_since') ?? 'Member Since',
            _formatJoinDate(_user?.createdAt),
            Icons.calendar_today,
            isDark,
          ),

          SizedBox(height: 16),
          _buildReadOnlyField(AppLocalizations.of(context)?.tr('phone') ?? 'Phone', _user?.phone ?? '', Icons.phone, isDark),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, bool isDark, {TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      enabled: _isEditing,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: isDark ? AppColors.darkAccent : AppColors.primary, size: 24),
        filled: true,
        fillColor: isDark ? AppColors.cardDark : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // New widget for read-only fields that displays value directly
  Widget _buildReadOnlyField(String label, String value, IconData icon, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: isDark ? AppColors.darkAccent : AppColors.primary, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value.isNotEmpty ? value : '-',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeDropdown(bool isDark) {
    return DropdownButtonFormField<String>(
      value: _selectedType,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context)?.tr('type') ?? 'Type',
        prefixIcon: Icon(Icons.badge, color: isDark ? AppColors.darkAccent : AppColors.primary, size: 24),
        filled: true,
        fillColor: isDark ? AppColors.cardDark : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      dropdownColor: isDark ? AppColors.cardDark : Colors.white,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      items: [
        DropdownMenuItem(value: 'guest', child: Text(AppLocalizations.of(context)?.tr('guest') ?? 'Guest')),
        DropdownMenuItem(value: 'player', child: Text('Player')),
        DropdownMenuItem(value: 'scout', child: Text(AppLocalizations.of(context)?.tr('scout') ?? 'Scout')),
      ],
      onChanged: null, // Type is not editable
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, bool isDark) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: isDark ? AppColors.darkAccent : AppColors.primary, size: 24),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowingSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context)?.tr('following') ?? 'Following',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Text(
                '${_followingList.length}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkAccent : AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _isLoadingFollowing
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
              : _followingList.isEmpty
              ? Container(
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 48,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context)?.tr('not_following_anyone') ?? 'You are not following anyone yet',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
              : ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _followingList.length,
            itemBuilder: (context, index) {
              final user = _followingList[index];
              return _buildFollowingCard(user, isDark);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFollowingCard(User user, bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerProfileScreen(userId: user.id),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Profile Photo
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.greyLight,
              backgroundImage: user.profilePhotoUrl != null
                  ? NetworkImage((user.profilePhotoUrl?.startsWith('http') ?? false)
                  ? user.profilePhotoUrl!
                  : 'http://187.124.37.68:3000${user.profilePhotoUrl}')
                  : null,
              child: user.profilePhotoUrl == null
                  ? Icon(Icons.person, size: 30, color: Colors.grey[600])
                  : null,
            ),
            SizedBox(width: 12),
            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      if (user.country != null) ...[
                        Icon(Icons.location_on, size: 14, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          AppLocalizations.of(context)?.tr(user.country!.toLowerCase().replaceAll(' ', '_')) ?? user.country!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                      if (user.position != null) ...[
                        SizedBox(width: 8),
                        Icon(Icons.sports_soccer, size: 14, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          AppLocalizations.of(context)?.tr(user.position!.toLowerCase().replaceAll(' ', '_')) ?? user.position!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Arrow Icon
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
