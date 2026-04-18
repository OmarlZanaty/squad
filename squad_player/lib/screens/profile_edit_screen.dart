import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/app_colors.dart';
import '../widgets/compression_preview_widget.dart';
import '../models/user.dart';
import '../models/post.dart';
import '../widgets/collage_selector_widget.dart';
import '../services/api_service.dart';
import 'adjust_image_position_screen.dart';
import 'create_post_screen.dart';
// import 'media_library_screen.dart'; // Hidden for now
import 'package:squad_player/utils/app_localizations.dart';
import 'package:squad_player/config/app_config.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;


class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false; // Toggle edit mode

  double _coverFocusX = 0;
  double _coverFocusY = 0;

  double _profileFocusX = 0;
  double _profileFocusY = 0;
  bool _pickingImage = false;
// ⚠️ IMPORTANT:
// Do NOT hardcode in production.
// This should come from backend or env config.

  // Controllers
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _currentClubController = TextEditingController();

  String? _selectedCountry;
  String? _selectedPosition;
  File? _profileImage;
  File? _coverImage;
  User? _user;
  bool _isUnregistered = false; // Checkbox state for غير مقيد

  // Posts management
  List<Post> _userPosts = [];
  bool _isLoadingPosts = false;

/*  final List<String> _countries = [
    'مصر', 'Saudi Arabia', 'UAE', 'Qatar', 'Kuwait',
    'Bahrain', 'Oman', 'Jordan', 'Lebanon', 'Iraq',
  ];
*//**/
// Remove lines 51-63 and add this getter method instead:
  List<String> get _positions => [
    AppLocalizations.of(context)!.tr('goalkeeper'),
    AppLocalizations.of(context)!.tr('right_back'),
    AppLocalizations.of(context)!.tr('left_back'),
    AppLocalizations.of(context)!.tr('center_back'),
    AppLocalizations.of(context)!.tr('defensive_midfielder'),
    AppLocalizations.of(context)!.tr('central_midfielder'),
    AppLocalizations.of(context)!.tr('attacking_midfielder'),
    AppLocalizations.of(context)!.tr('right_winger'),
    AppLocalizations.of(context)!.tr('left_winger'),
    AppLocalizations.of(context)!.tr('forward'),
    AppLocalizations.of(context)!.tr('striker'),
  ];

  // Position mapping: English <-> Translation Key
  final Map<String, String> _positionToKey = {
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

  // Get translation key from any language value
  String? _getKeyFromPosition(String position) {
    // First check if it's already English
    if (_positionToKey.containsKey(position)) {
      return _positionToKey[position];
    }

    // Check all translation keys
    final keys = [
      'goalkeeper', 'right_back', 'left_back', 'center_back',
      'defensive_midfielder', 'central_midfielder', 'attacking_midfielder',
      'right_winger', 'left_winger', 'forward', 'striker'
    ];

    for (var key in keys) {
      if (AppLocalizations.of(context)!.tr(key) == position) {
        return key;
      }
    }

    return null;
  }

  // Get current language translation from key
  String _getTranslationFromKey(String key) {
    return AppLocalizations.of(context)!.tr(key);
  }
  void _openProfileImageViewer() {
    final ImageProvider? provider = _profileImage != null
        ? FileImage(_profileImage!)
        : (_user?.profilePhotoUrl != null
        ? NetworkImage(AppConfig.getMediaUrl(_user!.profilePhotoUrl))
        : null);

    if (provider == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullScreenImageViewer(
          imageProvider: provider,
          heroTag: 'profile_image_hero',
        ),
      ),
    );
  }



  Future<File> _centerCropToSquare(File input) async {
    final bytes = await input.readAsBytes();
    final original = img.decodeImage(bytes);

    if (original == null) return input;

    final size = original.width < original.height
        ? original.width
        : original.height;

    final offsetX = (original.width - size) ~/ 2;
    final offsetY = (original.height - size) ~/ 2;

    final cropped = img.copyCrop(
      original,
      x: offsetX,
      y: offsetY,
      width: size,
      height: size,
    );

    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/profile_square_${DateTime.now().millisecondsSinceEpoch}.png',
    );

    await file.writeAsBytes(img.encodePng(cropped));
    return file;
  }


  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadUserPosts();
  }

  Future<File> _cropAvatarFromPngAlpha(File input) async {
    final bytes = await input.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return input;

    // Find bounding box of non-transparent pixels
    int minX = decoded.width, minY = decoded.height, maxX = 0, maxY = 0;
    bool found = false;

    for (int y = 0; y < decoded.height; y++) {
      for (int x = 0; x < decoded.width; x++) {
        final p = decoded.getPixel(x, y);
        final a = p.a; // ✅ FIX
        if (a > 10) {
          found = true;
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
        }
      }
    }


    // If no alpha pixels found, fallback to old center square crop
    if (!found) return await _centerCropToSquare(input);

    final subjectW = (maxX - minX + 1);
    final subjectH = (maxY - minY + 1);

    // Add padding around subject
    final pad = (subjectW > subjectH ? subjectW : subjectH) * 0.35; // 35% padding
    double left = minX - pad;
    double right = maxX + pad;
    double top = minY - pad * 1.2;   // extra headroom (important)
    double bottom = maxY + pad * 0.6;

    // Clamp to image bounds
    left = left.clamp(0, (decoded.width - 1).toDouble());
    top = top.clamp(0, (decoded.height - 1).toDouble());
    right = right.clamp(0, (decoded.width - 1).toDouble());
    bottom = bottom.clamp(0, (decoded.height - 1).toDouble());

    // Make it square (expand the shorter side)
    double cropW = right - left;
    double cropH = bottom - top;
    final side = cropW > cropH ? cropW : cropH;

    // Center square around current crop area
    final cx = (left + right) / 2;
    final cy = (top + bottom) / 2;

    double sqLeft = cx - side / 2;
    double sqTop = cy - side / 2;
    double sqRight = cx + side / 2;
    double sqBottom = cy + side / 2;

    // Clamp square again
    if (sqLeft < 0) { sqRight -= sqLeft; sqLeft = 0; }
    if (sqTop < 0) { sqBottom -= sqTop; sqTop = 0; }
    if (sqRight > decoded.width - 1) {
      final diff = sqRight - (decoded.width - 1);
      sqLeft -= diff; sqRight = (decoded.width - 1).toDouble();
      if (sqLeft < 0) sqLeft = 0;
    }
    if (sqBottom > decoded.height - 1) {
      final diff = sqBottom - (decoded.height - 1);
      sqTop -= diff; sqBottom = (decoded.height - 1).toDouble();
      if (sqTop < 0) sqTop = 0;
    }

    final cropX = sqLeft.round();
    final cropY = sqTop.round();
    final cropSize = (sqRight - sqLeft).round().clamp(1, 5000);

    final cropped = img.copyCrop(
      decoded,
      x: cropX,
      y: cropY,
      width: cropSize,
      height: cropSize,
    );

    final tempDir = await getTemporaryDirectory();
    final out = File('${tempDir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.png');
    await out.writeAsBytes(img.encodePng(cropped), flush: true);
    return out;
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userId = prefs.getInt('user_id');

      print('ProfileEditScreen: Loading user data for user $userId');

      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/users/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timed out after 10 seconds');
        },
      );

      print('ProfileEditScreen: Response status ${response.statusCode}');
      print('ProfileEditScreen: Response body ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        print('ProfileEditScreen: Parsed data successfully');

        // FIX: Check if the user data is nested inside a 'user' or 'data' key
        Map<String, dynamic> userJson;
        if (responseData.containsKey('user')) {
          userJson = responseData['user'];
        } else if (responseData.containsKey('data')) {
          userJson = responseData['data'];
        } else {
          userJson = responseData;
        }

        _user = User.fromJson(userJson);

        setState(() {
          _nameController.text = _user!.name;
          _bioController.text = _user!.bio ?? '';
          _weightController.text = _user!.weight?.toString() ?? '';
          _heightController.text = _user!.height?.toString() ?? '';

          // Populate birthday controller if a date exists
          if (_user!.birthDate != null && _user!.birthDate!.isNotEmpty) {
            // split off any time portion (e.g. 2006-04-25T00:00:00.000Z -> 2006-04-25)
            final parts = _user!.birthDate!.split('T');
            _birthdayController.text = parts.first;
          } else {
            _birthdayController.text = '';
          }

          _currentClubController.text = _user!.currentClub ?? '';
          _isLoading = false;
        });
      }

    } catch (e) {
      print('Error loading user data: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectBirthday() async {
    if (!_isEditing) return;

    DateTime initialDate;
    if (_birthdayController.text.isNotEmpty) {
      try {
        initialDate = DateTime.parse(_birthdayController.text);
      } catch (_) {
        initialDate = DateTime.now().subtract(const Duration(days: 365 * 18));
      }
    } else {
      initialDate = DateTime.now().subtract(const Duration(days: 365 * 18));
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
              primary: AppColors.darkAccent,
              onPrimary: Colors.white,
              surface: AppColors.cardDark,
              onSurface: Colors.white,
            )
                : ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthdayController.text = picked.toIso8601String().split('T')[0];
      });
    }
  }

  Future<void> _pickImage(bool isProfile) async {
    if (_pickingImage) return;
    _pickingImage = true;

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: isProfile ? 512 : 1024,
        maxHeight: isProfile ? 512 : 1024,
        imageQuality: isProfile ? 80 : 85,
      );

      if (pickedFile == null) return;

      final selectedFile = File(pickedFile.path);

      // =========================
      // COVER IMAGE
      // =========================
      if (!isProfile) {
        final res = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdjustImagePositionScreen(
              imageFile: selectedFile,
              aspectRatio: 16 / 9,
              isCircle: false,
              title: 'Adjust cover',
              initialFocusX: _coverFocusX,
              initialFocusY: _coverFocusY,
            ),
          ),
        );

        if (!mounted) return;

        setState(() {
          _coverImage = selectedFile;
          if (res is AdjustImagePositionResult) {
            _coverFocusX = res.focusX;
            _coverFocusY = res.focusY;
          }
        });

        return;
      }

      // =========================
      // PROFILE IMAGE
      // =========================
      // =========================
// PROFILE IMAGE (NO pre-crop)
// =========================
      final File fileToAdjust = selectedFile; // ✅ no _centerCropToSquare here

      if (!mounted) return;

      setState(() {
        _profileImage = fileToAdjust;
      });

      final adjust = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdjustImagePositionScreen(
            imageFile: fileToAdjust,
            aspectRatio: 1,
            isCircle: true,
            title: AppLocalizations.of(context)?.tr('adjust_profile_photo') ??
                'Adjust profile photo',
            initialFocusX: _profileFocusX,
            initialFocusY: _profileFocusY,
          ),
        ),
      );

      if (!mounted) return;

      if (adjust is AdjustImagePositionResult) {
        setState(() {
          _profileFocusX = adjust.focusX;
          _profileFocusY = adjust.focusY;
        });
      }
    } catch (e) {
      // Any error (including picker issues)
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image: $e'),
          backgroundColor: Colors.orange,
        ),
      );
    } finally {
      _pickingImage = false;
    }
  }


  void _enableEditing() {
    setState(() {
      _isEditing = true;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userId = prefs.getInt('user_id');

      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('http://187.124.37.68:3000/api/auth/update-profile'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      // Add text fields (using English field names for API)
      request.fields['name'] = _nameController.text;
      request.fields['bio'] = _bioController.text;
      // Always send current_club, even if empty
      if (_isUnregistered) {
        request.fields['current_club'] = AppLocalizations.of(context)?.tr('unrestricted') ?? 'Unrestricted';
      } else {
        request.fields['current_club'] = _currentClubController.text.trim();
      }

      print('ProfileEditScreen: Sending current_club = ${request.fields['current_club']}');
      print('ProfileEditScreen: _isUnregistered = $_isUnregistered');

      request.fields['country'] = _selectedCountry ?? '';

      // Convert current language position to English for database
      if (_selectedPosition != null && _selectedPosition!.isNotEmpty) {
        String? key = _getKeyFromPosition(_selectedPosition!);
        if (key != null) {
          // Save English version to database
          String englishPosition = _positionToKey.entries
              .firstWhere((entry) => entry.value == key)
              .key;
          request.fields['position'] = englishPosition;
        } else {
          request.fields['position'] = _selectedPosition!;
        }
      } else {
        request.fields['position'] = '';
      }

      if (_weightController.text.isNotEmpty) {
        request.fields['weight'] = _weightController.text;
      }
      if (_heightController.text.isNotEmpty) {
        request.fields['height'] = _heightController.text;
      }
      if (_birthdayController.text.isNotEmpty) {
        // Send as both just in case the backend is picky
        request.fields['birthday'] = _birthdayController.text;
        request.fields['birth_date'] = _birthdayController.text;
      }




      // Add images if selected
      if (_profileImage != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'profile_photo',
          _profileImage!.path,
        ));
      }

      if (_coverImage != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'cover_photo',
          _coverImage!.path,
        ));
      }

      request.fields['cover_focus_x'] = _coverFocusX.toString();
      request.fields['cover_focus_y'] = _coverFocusY.toString();
      request.fields['profile_focus_x'] = _profileFocusX.toString();
      request.fields['profile_focus_y'] = _profileFocusY.toString();

      print('ProfileEditScreen: Sending update request');
      final response = await request.send().timeout(
        Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Update request timed out after 30 seconds');
        },
      );
      print('ProfileEditScreen: Update response status ${response.statusCode}');

      if (response.statusCode == 200) {
        print('ProfileEditScreen: Save successful, checking mounted state');

        if (!mounted) {
          print('ProfileEditScreen: Widget not mounted, returning');
          return;
        }

        print('ProfileEditScreen: Showing success message');

        // Show success message
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text(AppLocalizations.of(context)!.tr('profile_updated_successfully')),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          print('ProfileEditScreen: Success message shown');
        } catch (e) {
          print('ProfileEditScreen: Error showing snackbar: $e');
        }

        // Disable editing mode after successful save
        setState(() {
          _isEditing = false;
        });

        print('ProfileEditScreen: Edit mode disabled after save');

        if (!mounted) {
          print('ProfileEditScreen: Widget not mounted after delay, returning');
          return;
        }

        print('ProfileEditScreen: Navigating back');
        if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        } else {
          // Always works even without named routes
          Navigator.of(context).popUntil((route) => route.isFirst);
        }


      } else {
        final responseBody = await response.stream.bytesToString();
        throw Exception('Failed to update profile: ${response.statusCode} - $responseBody');
      }
    } catch (e) {
      print('ProfileEditScreen: Exception caught: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      print('ProfileEditScreen: Finally block, setting _isSaving to false');
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.tr('edit_profile')),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving ? null : (_isEditing ? _saveProfile : _enableEditing),
              child: _isSaving
                  ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Text(
                _isEditing ? AppLocalizations.of(context)?.tr('save') ?? 'Save' : AppLocalizations.of(context)?.tr('edit') ?? 'Edit', // Arabic: Save or Edit
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
        onRefresh: () async {
          await _loadUserData();
          await _loadUserPosts();
        },
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(), // Enable pull-to-refresh
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCoverPhotoSection(isDark),
                _buildProfilePhotoSection(isDark),
                SizedBox(height: 20),
                _buildFormSection(isDark),
                SizedBox(height: 20),
                _buildMediaButtons(isDark),
                SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),

    );
  }

  Widget _buildMediaButtons(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          // Media Library and Create Collage buttons hidden for now
        ],
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
              ? Image.file(_coverImage!, fit: BoxFit.cover, alignment: Alignment(_coverFocusX, _coverFocusY))
              : (_user?.coverPhotoUrl != null
              ? Image.network(
            AppConfig.getMediaUrl(_user!.coverPhotoUrl),
            fit: BoxFit.cover,
            alignment: Alignment(_coverFocusX, _coverFocusY),
            errorBuilder: (_, __, ___) => Container(),
          )

              : Center(
            child: Icon(
              Icons.photo_camera,
              size: 50,
              color: Colors.grey,
            ),
          )),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.small(
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
              child: GestureDetector(
                  onTap: _isEditing ? null : _openProfileImageViewer,
                  child: ClipOval(
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: _profileImage != null
                        ? Image.file(_profileImage!, fit: BoxFit.cover, alignment: Alignment(_profileFocusX, _profileFocusY))
                        : (_user?.profilePhotoUrl != null
                        ? Image.network(AppConfig.getMediaUrl(_user!.profilePhotoUrl),
                        fit: BoxFit.cover,
                        alignment: Alignment(_profileFocusX, _profileFocusY),
                        errorBuilder: (_, __, ___) => const SizedBox())
                        : Container(
                      color: AppColors.greyLight,
                      child: Icon(Icons.person, size: 60, color: isDark ? Colors.grey[600] : AppColors.grey),
                    )),
                  ),
                )


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

  Widget _buildFormSection(bool isDark) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /*Text(
            AppLocalizations.of(context)?.tr('personal_information') ?? 'Personal Information', // Arabic: Personal Information
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),*/
          SizedBox(height: 20),
          _buildTextField(AppLocalizations.of(context)?.tr('full_name') ?? 'Full Name', _nameController, Icons.person, isDark),

          SizedBox(height: 16),
/*          _buildDropdown(AppLocalizations.of(context)?.tr('country') ?? 'Country', _selectedCountry, _countries, Icons.flag, isDark, (value) {
            setState(() => _selectedCountry = value);
          })*/
          SizedBox(height: 16),
          _buildDropdown(AppLocalizations.of(context)?.tr('position') ?? 'Position', _selectedPosition, _positions, Icons.sports_soccer, isDark, (value) {
            setState(() => _selectedPosition = value);
          }),
          SizedBox(height: 24),
          /*Text(
            AppLocalizations.of(context)?.tr('physical_stats') ?? 'Physical Stats', // Arabic: Physical Stats
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),*/
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildTextField(AppLocalizations.of(context)?.tr('weight_kg') ?? 'Weight (kg)', _weightController, Icons.fitness_center, isDark,
                    keyboardType: TextInputType.number),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildTextField(AppLocalizations.of(context)?.tr('height_cm') ?? 'Height (cm)', _heightController, Icons.height, isDark,
                    keyboardType: TextInputType.number),
              ),
            ],
          ),
/*          SizedBox(height: 16),
          InkWell(
            onTap: _isEditing ? () async {
              DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now().subtract(Duration(days: 365 * 20)),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (pickedDate != null) {
                setState(() {
                  _birthdayController.text = "${pickedDate.toLocal()}".split(' ')[0];
                });
              }
            } : null,
            child: AbsorbPointer(
              child: _buildTextField(
                AppLocalizations.of(context)?.tr('birthdate') ?? 'Birthdate',
                _birthdayController,
                Icons.cake,
                isDark,
                readOnly: true,
                //onTap: _selectBirthday,
              ),
            ),
          ),*/

          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(AppLocalizations.of(context)?.tr('current_club') ?? 'Current Club', _currentClubController, Icons.shield, isDark, readOnly: _isUnregistered),
              ),
              SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _isUnregistered,
                    onChanged: _isEditing ? (value) {
                      setState(() {
                        _isUnregistered = value ?? false;
                        if (_isUnregistered) {
                          _currentClubController.text = AppLocalizations.of(context)?.tr('unrestricted') ?? 'Unrestricted';
                        } else {
                          _currentClubController.clear();
                        }
                      });
                    } : null,
                    activeColor: AppColors.primary,
                  ),
                  Text(AppLocalizations.of(context)?.tr('unrestricted') ?? 'Unrestricted', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),

          SizedBox(height: 16),
          _buildTextField(AppLocalizations.of(context)?.tr('bio') ?? 'Bio', _bioController, Icons.info, isDark, maxLines: 3),

        ],
      ),
    );
  }

  Widget _buildTextField(
      String label,
      TextEditingController controller,
      IconData icon,
      bool isDark, {
        int maxLines = 1,
        TextInputType keyboardType = TextInputType.text,
        bool readOnly = false,
      }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      enabled: _isEditing, // Disable when not editing
      readOnly: readOnly, // Make read-only if checkbox is checked
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: isDark ? AppColors.darkAccent : AppColors.primary),
        filled: true,
        fillColor: isDark ? AppColors.cardDark : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? AppColors.darkAccent : AppColors.primary, width: 2),
        ),
      ),
      validator: (value) {
        if (label == 'Full Name' && (value == null || value.isEmpty)) {
          return 'Please enter your name';
        }
        return null;
      },
    );
  }

  Widget _buildDropdown(
      String label,
      String? value,
      List<String> items,
      IconData icon,
      bool isDark,
      Function(String?) onChanged,
      ) {
    final validValue = (value != null && items.contains(value)) ? value : null;

    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
      ),
      child: DropdownButtonFormField<String>(
        value: validValue,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            icon,
            color: isDark ? AppColors.darkAccent : AppColors.primary,
          ),
          filled: true,
          fillColor: isDark ? AppColors.cardDark : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? AppColors.darkAccent : AppColors.primary,
              width: 2,
            ),
          ),
        ),
        dropdownColor: isDark ? AppColors.cardDark : Colors.white,
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: _isEditing ? onChanged : null,
      ),
    );
  }


  Future<void> _loadUserPosts() async {
    setState(() => _isLoadingPosts = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userId = prefs.getInt('user_id');

      if (token == null || userId == null) return;

      final result = await ApiService.getUserPosts(
        token: token,
        userId: userId,
      );

      if (result is List) {
        final List<Post> posts = [];
        for (var item in result) {
          posts.add(Post.fromJson(item as Map<String, dynamic>));
        }
        setState(() {
          _userPosts = posts;
          _isLoadingPosts = false;
        });
      }
    } catch (e) {
      print('Error loading posts: $e');
      setState(() => _isLoadingPosts = false);
    }
  }

  Future<void> _deletePost(int postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.tr('delete_post') ?? 'Delete Post'), // Arabic: Delete Post
        content: Text(AppLocalizations.of(context)?.tr('confirm_delete_post') ?? 'Are you sure you want to delete this post?'), // Arabic: Are you sure you want to delete this post?
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)?.tr('cancel') ?? 'Cancel'), // Arabic: Cancel
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)?.tr('delete') ?? 'Delete', style: TextStyle(color: Colors.red)), // Arabic: Delete
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) return;

      final result = await ApiService.deletePost(
        token: token,
        postId: postId,
      );

      // Check if response indicates success (either success: true or message contains success)
      if (result['success'] == true || result['message']?.toString().contains('success') == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)?.tr('post_deleted_successfully') ?? 'Post deleted successfully'), // Arabic: Post deleted successfully
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadUserPosts(); // Reload posts
      } else {
        throw Exception(result['message'] ?? 'Failed to delete post');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting post: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildMyPostsSection(bool isDark) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)?.tr('my_posts') ?? 'My Posts', // Arabic: My Posts
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          SizedBox(height: 16),
          if (_isLoadingPosts)
            Center(child: CircularProgressIndicator())
          else if (_userPosts.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.article_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)?.tr('no_posts_yet') ?? 'No posts yet', // Arabic: No posts yet
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)?.tr('create_first_post') ?? 'Create your first post using the button below', // Arabic: Create your first post using the button below
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _userPosts.length,
              itemBuilder: (context, index) {
                final post = _userPosts[index];
                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  color: isDark ? AppColors.cardDark : Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (post.mediaUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                          child: Image.network(
                            'http://187.124.37.68:3000${post.mediaUrl}',
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 200,
                              color: Colors.grey[300],
                              child: Icon(Icons.broken_image, size: 50),
                            ),
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (post.caption != null && post.caption!.isNotEmpty)
                              Text(
                                post.caption!,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.favorite, size: 16, color: Colors.red),
                                    SizedBox(width: 4),
                                    Text('${post.likeCount + post.loveCount + post.talentCount + post.amazingCount}'),
                                  ],
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deletePost(post.id),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _birthdayController.dispose();
    _currentClubController.dispose();
    super.dispose();
  }
}



class _FullScreenImageViewer extends StatelessWidget {
  final ImageProvider imageProvider;
  final String heroTag;

  const _FullScreenImageViewer({
    required this.imageProvider,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Hero(
              tag: heroTag,
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5.0,
                child: Image(
                  image: imageProvider,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
