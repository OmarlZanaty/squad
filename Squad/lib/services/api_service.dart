import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:squad/models/user.dart';
import 'package:squad/main.dart';
import 'package:squad/services/auth_service.dart';
import 'package:squad/screens/login_screen.dart';
import 'package:squad/models/app_notification.dart';
import '../models/comment.dart';
import 'package:squad/models/home_ad.dart';

class ApiService {
  // Update this to your backend URL
  static const String baseUrl = 'http://187.124.37.68:3000/api';

  // Auth endpoints
  static Future<dynamic> register({
    required String name,

    required String phone,
    required String password,
    required String role,
    String? country,
    String? position,
  }) async {
    try {
      final Map<String, dynamic> body = {'name': name,  'phone': phone, 'password': password, 'type': role};

      if (country != null) body['country'] = country;
      if (position != null) body['position'] = position;

      final response = await http.post(Uri.parse('$baseUrl/auth/register'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));

      return _handleResponse(response, forceLogoutOnAuthError: false);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getPlayersWithCount({
    required String token,
    String sort = 'new',
    int limit = 100,
    int offset = 0,
  }) async {
    final url = Uri.parse(
      '$baseUrl/users/players?sort=$sort&limit=$limit&offset=$offset',
    );


    final res = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (res.statusCode != 200) {
      throw Exception('getPlayersWithCount failed: ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body);

    // ❗ IMPORTANT: adapt based on your backend response
    return {
      "players": (decoded["players"] ?? [])
          .map<User>((e) => User.fromJson(e))
          .toList(),
      "total": decoded["total"] ?? 0,
    };
  }

  static Future<dynamic> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    try {
      final Map<String, dynamic> body = {
        "password": password,
      };

      if (phone != null && phone.isNotEmpty) {
        body["phone"] = phone;
      } else if (email != null && email.isNotEmpty) {
        body["email"] = email;
      }

      print("🚀 LOGIN BODY: $body");

      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      return _handleResponse(response, forceLogoutOnAuthError: false);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<void> recordProfileShare({
    required int profileUserId,
    required String platform,
  }) async {

    final token = await AuthService.getToken();

    final res = await http.post(
      Uri.parse('$baseUrl/profiles/$profileUserId/share'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'platform': platform,
      }),
    );

    print("PROFILE SHARE STATUS: ${res.statusCode}");
  }
  static Future<void> recordPostShare({
    required int postId,
    String? platform,
  }) async {
    try {
      final token = await AuthService.getToken();

      final res = await http.post(
        Uri.parse('$baseUrl/posts/$postId/share'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'platform': platform ?? 'unknown'}),
      );

      print("SHARE API STATUS: ${res.statusCode}");
      print("SHARE API BODY: ${res.body}");

    } catch (e) {
      debugPrint('Share tracking failed: $e');
    }
  }

  static String toAbsoluteUrl(String? url) {
    final u = (url ?? '').trim();
    if (u.isEmpty) return '';
    if (u.startsWith('http://') || u.startsWith('https://')) return u;

    final base = ApiService.baseUrl; // e.g. http://187.124.37.68:3000/api
    final origin = base.replaceAll(RegExp(r'/api/?$'), '');
    if (u.startsWith('/')) return '$origin$u';
    return '$origin/$u';
  }

  static Future<List<HomeAd>> getHomeAds() async {
    // The backend does not have an /ads/active route; /ads returns the ads list.
    final res = await http.get(
      Uri.parse('$baseUrl/ads/ads'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );

    final handled = _handleResponse(res, forceLogoutOnAuthError: false);
    List rawList = [];

    if (handled is Map && handled['data'] is Map) {
      final data = Map<String, dynamic>.from(handled['data']);
      if (data['items'] is List) {
        rawList = List.from(data['items']);
      } else if (data['ads'] is List) {
        rawList = List.from(data['ads']);
      }
    } else if (handled is Map && handled['data'] is List) {
      rawList = List.from(handled['data']);
    } else if (handled is List) {
      rawList = List.from(handled);
    }

    return rawList
        .whereType<Map>()
        .map((raw) {
      final map = Map<String, dynamic>.from(raw);
      // Normalise snake_case to camelCase expected by HomeAd
      if (map.containsKey('image_url') && !map.containsKey('imageUrl')) {
        map['imageUrl'] = map['image_url'];
      }
      if (map.containsKey('final_image_url') &&
          !map.containsKey('finalImageUrl')) {
        map['finalImageUrl'] = map['final_image_url'];
      }
      if (map.containsKey('description') && !map.containsKey('subtitle')) {
        map['subtitle'] = map['description'];
      }
      return HomeAd.fromJson(map);
    })
        .toList();
  }

  static Future<Map<String, dynamic>> getNotifications({
    required String token,
    int page = 1,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications?page=$page'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> markNotificationAsRead({
    required String token,
    required int id,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/notifications/$id/read'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> markAllNotificationsAsRead({
    required String token,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/notifications/read-all'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteNotification({
    required String token,
    required int id,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/notifications/$id'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<dynamic> pinChat(String token, int chatId, bool pinned) async {
    final uri = Uri.parse('$baseUrl/chats/$chatId/pin');
    final res = await http.patch(uri, headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: jsonEncode({'pinned': pinned}));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to pin chat: ${res.statusCode} ${res.body}');
  }

  static Future<dynamic> archiveChat(String token, int chatId, bool archived) async {
    final uri = Uri.parse('$baseUrl/chats/$chatId/archive');
    final res = await http.patch(
      uri,
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'archived': archived}),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to archive chat: ${res.statusCode} ${res.body}');
  }

  static Future<Map<String, dynamic>> getProfile(String token) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/auth/profile'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'});

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateProfile({
    required String token,
    String? name,
    String? bio,
    String? country,
    String? position,
    String? profilePhotoUrl,
    String? coverPhotoUrl,
  }) async {
    try {
      final Map<String, dynamic> body = {};

      if (name != null && name.isNotEmpty) body['name'] = name;
      if (bio != null) body['bio'] = bio;
      if (country != null) body['country'] = country;
      if (position != null) body['position'] = position;
      if (profilePhotoUrl != null) body['profilePhotoUrl'] = profilePhotoUrl;
      if (coverPhotoUrl != null) body['coverPhotoUrl'] = coverPhotoUrl;

      final response = await http.put(
        Uri.parse('$baseUrl/auth/profile'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(body),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<dynamic> forgotPassword({
    String? email,
    String? phone,
  }) async {
    try {
      final Map<String, dynamic> body = {};

      if (phone != null) {
        body["phone"] = phone;
      } else if (email != null) {
        body["email"] = email;
      } else {
        return {'success': false, 'message': 'Email or phone required'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      return _handleResponse(response, forceLogoutOnAuthError: false);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> sendPasswordResetOtp({
    required String phone,
    required String verificationMethod, // 'sms' or 'whatsapp'
  }) async {
    final uri = Uri.parse('$baseUrl/auth/password-reset/send-otp');

    debugPrint('📤 RESET OTP SEND REQUEST');
    debugPrint('📞 phone: $phone');
    debugPrint('📝 method: $verificationMethod');
    debugPrint('🌍 url: $uri');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'verification_method': verificationMethod, // keep consistent with your API style
        }),
      );

      debugPrint('📥 RESET OTP SEND STATUS: ${response.statusCode}');
      debugPrint('📥 RESET OTP SEND BODY: ${response.body}');

      final handled = _handleResponse(response, forceLogoutOnAuthError: false);

      if (handled is Map<String, dynamic>) return handled;

      return {
        'success': false,
        'message': 'RESET_OTP_SEND_FAILED',
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> verifyPasswordResetOtpAndSetPassword({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/password-reset/verify-otp');

    debugPrint('📤 RESET OTP VERIFY REQUEST');
    debugPrint('📞 phone: $phone');
    debugPrint('🔢 otp: $otp');
    debugPrint('🌍 url: $uri');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'otp_code': otp,          // consistent with verifyOtp()
          'newPassword': newPassword,
        }),
      );

      debugPrint('📥 RESET OTP VERIFY STATUS: ${response.statusCode}');
      debugPrint('📥 RESET OTP VERIFY BODY: ${response.body}');

      final handled = _handleResponse(response, forceLogoutOnAuthError: false);

      if (handled is Map<String, dynamic>) return handled;

      return {
        'success': false,
        'message': 'RESET_OTP_VERIFY_FAILED',
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<dynamic> reactToComment({
    required String token,
    required int commentId,
    required String reaction, // "like" or "dislike"
  }) async {
    final url = Uri.parse('$baseUrl/comments/$commentId/reaction'); // ✅ FIX
    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'reaction': reaction}),
    );

    debugPrint('🧾 REACT url=$url');
    debugPrint('🧾 REACT status=${res.statusCode}');
    debugPrint('🧾 REACT body=${res.body}');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to react: ${res.statusCode} ${res.body}');
    }
    return res.body.trim().isEmpty ? {} : jsonDecode(res.body);
  }

  static Future<dynamic> removeCommentReaction({
    required String token,
    required int commentId,
  }) async {
    final url = Uri.parse('$baseUrl/comments/$commentId/reaction'); // ✅ FIX
    final res = await http.delete(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    debugPrint('🧾 UNREACT url=$url');
    debugPrint('🧾 UNREACT status=${res.statusCode}');
    debugPrint('🧾 UNREACT body=${res.body}');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to remove reaction: ${res.statusCode} ${res.body}');
    }
    return res.body.trim().isEmpty ? {} : jsonDecode(res.body);
  }


  static Future<void> incrementProfileView({
    required String token,
    required int userId,
  }) async {
    final url = Uri.parse('$baseUrl/users/$userId/view'); // <-- adjust if your route differs

    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    debugPrint('👁️ incrementProfileView => ${res.statusCode} ${res.body}');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('incrementProfileView failed: ${res.statusCode}');
    }
  }


  static Future<List<User>> getMostActivePlayers({
    required String token,
    int limit = 10,
  }) async {
    final url = Uri.parse('$baseUrl/users/most-active?limit=$limit');

    final res = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    if (res.statusCode != 200) {
      throw Exception('getMostActivePlayers failed');
    }

    final List data = jsonDecode(res.body);
    return data.map((e) => User.fromJson(e)).toList();
  }

  static Future<List<User>> getMostViewedPlayers({
    required String token,
    int limit = 100,
  }) async {
    final url = Uri.parse('$baseUrl/users/most-viewed?limit=$limit');

    final res = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    if (res.statusCode != 200) {
      throw Exception('getMostViewedPlayers failed: ${res.statusCode} ${res.body}');
    }

    final List data = jsonDecode(res.body);
    return data.map((e) => User.fromJson(e)).toList();
  }


  static Future<dynamic> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token, 'newPassword': newPassword}),
      );
      return _handleResponse(response, forceLogoutOnAuthError: false);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Post endpoints
  static Future<dynamic> getPosts(
      String token, {
        String? role,
        String? lastCreatedAt,
      }) async {
    try {
      String url = '$baseUrl/posts?limit=20&';

      if (lastCreatedAt != null) {
        url += 'lastCreatedAt=$lastCreatedAt&';
      }

      if (role != null && role.isNotEmpty) {
        url += 'role=$role&';
      }

      final response = await safeRequest(() {
        return http
            .get(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
            .timeout(const Duration(seconds: 10));
      });

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<T> safeRequest<T>(Future<T> Function() request) async {
    int retries = 2;

    for (int i = 0; i < retries; i++) {
      try {
        return await request();
      } catch (e) {
        if (i == retries - 1) rethrow;
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    throw Exception("Request failed after retries");
  }


  static Future<dynamic> getPostById(String token, int postId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/posts/$postId'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'});

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<List<User>> getPlayers({required String token, String sort = 'new', int limit = 200, int offset = 0}) async {
    final url = Uri.parse('$baseUrl/users/players?sort=$sort&limit=$limit&offset=$offset');

    final res = await http.get(url, headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'});

    if (res.statusCode != 200) {
      throw Exception('getPlayers failed: ${res.statusCode} ${res.body}');
    }

    final List data = jsonDecode(res.body);
    debugPrint('👑 first player raw = ${data.isNotEmpty ? data.first : "EMPTY"}');

    final users = data.map((e) => User.fromJson(e)).toList();

    // ✅ FILTER HERE
    // Proposed fix for ApiService.searchUsers
    final visible = users.where((u ) {
      // Only return users who are 'player' type AND 'active' status
      return (u.type ?? '').toLowerCase() == 'player' && (u.status ?? '').toLowerCase() == 'active';
    }).toList();

    return visible;
  }

  static Future<Map<String, dynamic>> createPost({required String token, required String content, String? mediaPath}) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/posts/upload'));

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['caption'] = content;

      if (mediaPath != null && mediaPath.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath('media', mediaPath));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> reactToPost({required String token, required int postId, required String reactionType}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/react'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'reaction_type': reactionType}),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deletePost({required String token, required int postId}) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/posts/$postId'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'});

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // User Profile endpoints
  static Future<Map<String, dynamic>> getUserProfile({required String token, required int userId}) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/users/$userId'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'});

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<dynamic> getUserPosts({required String token, required int userId}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/posts'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Follow endpoints
  static Future<Map<String, dynamic>> followUser({required String token, required int userId}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/$userId/follow'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> unfollowUser({required String token, required int userId}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/$userId/unfollow'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getFollowers(String token) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/follow/followers'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'});

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getFollowing(String token) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/follow/following'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'});

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Search users by name or position - FIXED VERSION
  static Future<List<User>> searchUsers({required String token, required String query}) async {
    try {
      print('🔍 Searching for: $query');
      print('🔗 URL: $baseUrl/users/search?q=$query');
      print('🔑 Token: ${token.substring(0, 20)}...');

      final url = Uri.parse('$baseUrl/users/search?q=${Uri.encodeComponent(query)}');
      print('📡 Full URL: $url');

      final response = await http.get(url, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'});

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('✅ Found ${data.length} users');

        final users = data.map((json) => User.fromJson(json)).toList();

        // ✅ FILTER HERE
        final visible = users.where((u) {
          if ((u.type ?? '').toLowerCase() != 'player') return true;
          final st = (u.status ?? '').toLowerCase();
          return st == 'active';
        }).toList();

        return visible;
      } else {
        print('❌ Search failed: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to search users: ${response.body}');
      }
    } catch (e) {
      print('💥 Search error: $e');
      throw Exception('Error searching users: $e');
    }
  }

  // ApiService.dart
  static Future<dynamic> updateComment({required String token, required int commentId, required String commentText}) async {
    final url = Uri.parse('$baseUrl/comments/$commentId');

    print('🧾 UPDATE COMMENT URL: $url');
    print('🧾 UPDATE COMMENT BODY: {comment_text: $commentText}');

    // ✅ USE PUT (matches backend)
    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'comment_text': commentText.trim()}),
    );

    print('🧾 UPDATE COMMENT status: ${response.statusCode}');
    print('🧾 UPDATE COMMENT body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');

    // ✅ Success
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.trim().isEmpty) return {};
      return jsonDecode(response.body);
    }

    // ❌ Backend returned HTML (wrong route / wrong method)
    final body = response.body.trim();
    if (body.startsWith('<!DOCTYPE html') || body.startsWith('<html')) {
      throw Exception(
        'UPDATE_COMMENT_ENDPOINT_ERROR (${response.statusCode}): '
        'Wrong HTTP method or route',
      );
    }

    throw Exception('Failed to update comment: ${response.statusCode} ${response.body}');
  }

  // Chat endpoints
  static Future<dynamic> getChats(String token, {bool includeArchived = false}) async {
    try {
      print('📞 Getting chats list (includeArchived=$includeArchived)');

      final url = Uri.parse('$baseUrl/chats${includeArchived ? '?include_archived=1' : ''}');

      final response = await http.get(url, headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'});

      print('📞 Get chats status: ${response.statusCode}');
      print('📞 Get chats body: ${response.body}');

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> startChat({required String token, required int otherUserId}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chats/start'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'other_user_id': otherUserId}),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> sendMessage({required String token, required int chatId, required String message}) async {
    try {
      print('📤 Sending message to chatId: $chatId');
      print('📤 Message: $message');
      print('📤 URL: $baseUrl/chats/$chatId/send');

      final response = await http.post(
        Uri.parse('$baseUrl/chats/$chatId/send'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'message': message}),
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<dynamic> getMessages({required String token, required int chatId}) async {
    try {
      print('📨 Getting messages for chatId: $chatId');
      final response = await http.get(
        Uri.parse('$baseUrl/chats/$chatId/messages'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );

      print('📨 Get messages status: ${response.statusCode}');
      print('📨 Get messages body: ${response.body}');

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Update post
  static Future<Map<String, dynamic>> updatePost(String token, int postId, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(data),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Delete chat
  static Future<Map<String, dynamic>> deleteChat(String token, int chatId) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/chats/$chatId'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Delete message
  static Future<Map<String, dynamic>> deleteMessage(String token, int messageId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/messages/$messageId'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Comment endpoints
  // Comment endpoints (MATCH BACKEND ROUTES)

  // GET /api/comments/:postId
  static Future<dynamic> getComments({required String token, required int postId}) async {
    try {
      final url = Uri.parse('$baseUrl/comments/$postId');
      print('🧾 GET COMMENTS URL: $url');

      final response = await http.get(url, headers: {'Content-Type': 'application/json', 'Accept': 'application/json', 'Authorization': 'Bearer $token'});

      print('🧾 GET COMMENTS status: ${response.statusCode}');
      print('🧾 GET COMMENTS body start: ${response.body.substring(0, response.body.length > 120 ? 120 : response.body.length)}');

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // POST /api/comments/:postId
  static Future<dynamic> addComment({
    required String token,
    required int postId,
    required String content,
    int? parentCommentId,
  }) async {
    final url = Uri.parse('$baseUrl/comments/$postId');

    final body = {
      "comment_text": content,
      if (parentCommentId != null) "parent_comment_id": parentCommentId,
    };

    final res = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    return jsonDecode(res.body);
  }


  // DELETE /api/comments/:commentId
  static Future<Map<String, dynamic>> deleteComment({required String token, required int commentId}) async {
    try {
      final url = Uri.parse('$baseUrl/comments/$commentId');
      print('🧾 DELETE COMMENT URL: $url');

      final response = await http.delete(url, headers: {'Content-Type': 'application/json', 'Accept': 'application/json', 'Authorization': 'Bearer $token'});

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> sendOtp({required String phone, required String verificationMethod}) async {
    final uri = Uri.parse('$baseUrl/auth/send-otp');

    debugPrint('📤 OTP REQUEST');
    debugPrint('📞 phone: $phone');
    debugPrint('📝 verificationMethod: $verificationMethod');
    debugPrint('🌍 url: $uri');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'verification_method': verificationMethod}),
    );

    debugPrint('📥 OTP REQUEST STATUS: ${response.statusCode}');
    debugPrint('📥 OTP REQUEST BODY: ${response.body}');

    final handled = _handleResponse(response, forceLogoutOnAuthError: false);

    if (handled is Map<String, dynamic>) return handled;

    return {'success': false, 'message': 'OTP_REQUEST_FAILED', 'statusCode': response.statusCode};
  }

  static Future<Map<String, dynamic>> verifyOtp({required String phone, required String otp}) async {
    final uri = Uri.parse('$baseUrl/auth/verify-otp');

    debugPrint('📤 OTP VERIFY REQUEST');
    debugPrint('📞 phone: $phone');
    debugPrint('🔢 otp: $otp');
    debugPrint('🌍 url: $uri');

    final response = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'phone': phone, 'otp_code': otp}));

    debugPrint('📥 OTP VERIFY STATUS: ${response.statusCode}');
    debugPrint('📥 OTP VERIFY BODY: ${response.body}');

    final handled = _handleResponse(response, forceLogoutOnAuthError: false);

    if (handled is Map<String, dynamic>) return handled;

    return {'success': false, 'message': 'OTP_VERIFY_FAILED', 'statusCode': response.statusCode};
  }

  static Future<Map<String, dynamic>> loginWithOtp({required String phone, required String firebaseUid}) async {
    final uri = Uri.parse('$baseUrl/auth/login-otp');

    debugPrint('📤 OTP LOGIN REQUEST');
    debugPrint('📞 phone: $phone');
    debugPrint('🆔 firebaseUid: $firebaseUid');
    debugPrint('🌍 url: $uri');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'firebaseUid': firebaseUid, // ✅ IMPORTANT (camelCase)
      }),
    );

    debugPrint('📥 OTP LOGIN STATUS: ${response.statusCode}');
    debugPrint('📥 OTP LOGIN BODY: ${response.body}');

    final handled = _handleResponse(response, forceLogoutOnAuthError: false);

    if (handled is Map<String, dynamic>) return handled;

    return {'success': false, 'message': 'OTP_LOGIN_FAILED', 'statusCode': response.statusCode};
  }

  // Increment post view count
  static Future<Map<String, dynamic>> incrementPostView(int postId) async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/posts/$postId/view'), headers: {'Content-Type': 'application/json'});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Pin/Unpin post
  static Future<Map<String, dynamic>> pinPost({required String token, required int postId}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/pin'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Hide/Unhide post
  static Future<Map<String, dynamic>> hidePost({required String token, required int postId}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/hide'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ============ GOOGLE PLAY COMPLIANCE FEATURES ============

  // Report content (post, comment, or user)
  static Future<Map<String, dynamic>> reportContent({
    required String token,
    required int contentId,
    required String contentType,
    required String reason,
    String? details,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reports'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'content_id': contentId, 'content_type': contentType, 'reason': reason, 'details': details ?? ''}),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Block a user
  static Future<Map<String, dynamic>> blockUser({required String token, required int userId}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/$userId/block'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Unblock a user
  static Future<Map<String, dynamic>> unblockUser({required String token, required int userId}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/users/$userId/block'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Get blocked users list
  static Future<dynamic> getBlockedUsers(String token) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/users/blocked'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Delete account permanently
  static Future<Map<String, dynamic>> deleteAccount({required String token, required String password}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/auth/account'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'password': password}),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Check if user is blocked
  static Future<Map<String, dynamic>> isUserBlocked({required String token, required int userId}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/blocked'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Accept terms of use
  static Future<Map<String, dynamic>> acceptTerms(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/accept-terms'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Notification endpoints
  static Future<Map<String, dynamic>> getUnreadNotificationCount(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications/unread-count'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'count': 0, 'message': 'Network error: $e'};
    }
  }

  // Ads endpoints
  static Future<List<dynamic>> getActiveAds() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/ads/active'), headers: {'Content-Type': 'application/json'});

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List;
      } else {
        print('Failed to load ads: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching ads: $e');
      return [];
    }
  }

  // Prevent multiple redirects at the same time
  static bool _isForcingLogout = false;

  static Future<void> _forceLogoutToLogin() async {
    if (_isForcingLogout) return;
    _isForcingLogout = true;

    try {
      await AuthService.logout();

      final nav = appNavKey.currentState;
      if (nav == null) return;

      // Push login and remove all previous screens
      nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
    } finally {
      // Allow redirect again later (small delay avoids loops)
      await Future.delayed(const Duration(milliseconds: 800));
      _isForcingLogout = false;
    }
  }

  // Helper method to handle responses
  static dynamic _handleResponse(http.Response response, {bool forceLogoutOnAuthError = true}) {
    final body = response.body.trim();

    void maybeForceLogout() {
      if (forceLogoutOnAuthError && (response.statusCode == 401 || response.statusCode == 403)) {
        _forceLogoutToLogin();
      }
    }

    if (body.isEmpty) {
      maybeForceLogout();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true};
      }
      return {'success': false, 'message': 'Empty response (${response.statusCode})', 'statusCode': response.statusCode};
    }

    if (body.startsWith('<!DOCTYPE html') || body.startsWith('<html')) {
      maybeForceLogout();
      return {
        'success': false,
        'message': 'Server returned HTML (${response.statusCode}). Wrong endpoint or server route.',
        'statusCode': response.statusCode,
        'raw': body.substring(0, body.length > 200 ? 200 : body.length),
      };
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (e) {
      maybeForceLogout();
      return {
        'success': false,
        'message': 'Invalid JSON response (${response.statusCode}): $e',
        'statusCode': response.statusCode,
        'raw': body.substring(0, body.length > 200 ? 200 : body.length),
      };
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    maybeForceLogout();

    if (decoded is Map<String, dynamic>) {
      return {'success': false, 'message': decoded['message'] ?? 'Request failed (${response.statusCode})', 'statusCode': response.statusCode, 'data': decoded};
    }

    return {'success': false, 'message': 'Request failed (${response.statusCode})', 'statusCode': response.statusCode, 'data': decoded};
  }
}
