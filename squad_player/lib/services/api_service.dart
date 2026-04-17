import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:squad_player/models/user.dart';
import 'package:squad_player/config/app_config.dart';
import '../utils/session_handler.dart'; // add at top of api_service.dart


// Custom MultipartRequest to track upload progress
class ProgressMultipartRequest extends http.MultipartRequest {
  final void Function(int bytes, int totalBytes) onProgress;

  ProgressMultipartRequest(
      String method,
      Uri url, {
        required this.onProgress,
      }) : super(method, url);

  @override
  http.ByteStream finalize() {
    final byteStream = super.finalize();
    final total = contentLength;
    int bytesWritten = 0;

    final transformer = StreamTransformer.fromHandlers(
      handleData: (List<int> data, EventSink<List<int>> sink) {
        bytesWritten += data.length;
        onProgress(bytesWritten, total);
        sink.add(data);
      },
    );

    return http.ByteStream(byteStream.transform(transformer));
  }
}

class ApiService {
  // Update this to your backend URL
  static String get baseUrl => AppConfig.apiBaseUrl;

  // Auth endpoints
  static Future<Map<String, dynamic>> register({
    required String name,
    String? email,
    required String password,

    String? country,
    String? position,
    String? bio,
    String? currentClub,
    int? age,
    int? weight,
    int? height,
    String? fullName,
    required String address,
    String? birthDate,
    String? phone,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'name': name,
        'password': password,
        'type': 'player',
      };

      if (email != null) {
        body['email'] = email;
      }

      if (country != null) body['country'] = country;
      if (position != null) body['position'] = position;
      if (bio != null) body['bio'] = bio;
      if (currentClub != null) body['current_club'] = currentClub;
      if (age != null) body['age'] = age;
      if (weight != null) body['weight'] = weight;
      if (height != null) body['height'] = height;
      if (fullName != null) body['full_name'] = fullName;
      if (address != null) body['address'] = address;
      if (birthDate != null) body['birth_date'] = birthDate;
      if (phone != null) body['phone'] = phone;

      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      return _handleResponse(response, autoLogout: false);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> login({
    String? phone,        // ← use this
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'password': password,
        'type': 'player'
      }),
    );
    return _handleResponse(response, autoLogout: false);
  }

  static Future<Map<String, dynamic>> getProfile(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Post endpoints
  static Future<dynamic> getPosts(String token, {String? role}) async {
    try {
      String url = '$baseUrl/posts';
      if (role != null && role.isNotEmpty) {
        url += '?role=$role';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<dynamic> getPostById(String token, int postId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> createPost({
    required String token,
    required String content,
    String? mediaPath,
    Function(int, int)? onProgress,
  }) async {
    try {
      // USE Custom ProgressMultipartRequest instead of http.MultipartRequest
      var request = ProgressMultipartRequest(
        'POST',
        Uri.parse('$baseUrl/posts/upload'),
        onProgress: (bytes, total) {
          // This callback now tracks the UPLOAD progress
          if (onProgress != null) {
            onProgress(bytes, total);
          }
        },
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['caption'] = content;

      if (mediaPath != null && mediaPath.isNotEmpty) {
        final file = File(mediaPath);
        // Add file to request
        request.files.add(await http.MultipartFile.fromPath('media', mediaPath));
      }

      // Send the request
      // The onProgress callback above will be triggered during this send() call
      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw Exception('Upload timeout - file may be too large');
        },
      );

      // Get the response
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      print('Upload error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> reactToPost({
    required String token,
    required int postId,
    required String reactionType,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/react'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'reaction_type': reactionType,
        }),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deletePost({
    required String token,
    required int postId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> pinPost({
    required String token,
    required int postId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/pin'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> hidePost({
    required String token,
    required int postId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/hide'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> toggleHidePost({
    required String token,
    required int postId,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/posts/$postId/hide'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updatePost({
    required String token,
    required int postId,
    required String content,
    String? mediaPath,
    bool removeMedia = false,
  }) async {
    try {
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/posts/$postId'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['caption'] = content;

      if (removeMedia) {
        request.fields['remove_media'] = 'true';
      } else if (mediaPath != null) {
        final file = File(mediaPath);
        final ext = mediaPath.split('.').last.toLowerCase();
        final isVideo = ['mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'].contains(ext);

        request.files.add(
          await http.MultipartFile.fromPath(
            'media',
            file.path,
          ),
        );
        request.fields['media_type'] = isVideo ? 'video' : 'image';
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // User Profile endpoints
  static Future<Map<String, dynamic>> getUserProfile({
    required String token,
    required int userId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<dynamic> getUserPosts({
    required String token,
    required int userId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/posts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Follow endpoints
  static Future<Map<String, dynamic>> followUser({
    required String token,
    required int userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/$userId/follow'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> unfollowUser({
    required String token,
    required int userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/$userId/unfollow'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }



  static Future<List<dynamic>> getFollowers({
    required String token,
    required int userId,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/followers'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final handled = _handleResponse(response); // ✅ auto logout included

    if (handled is List) return handled;
    if (handled is Map && handled['success'] == false) {
      throw Exception(handled['message'] ?? 'Failed to load followers');
    }

    throw Exception('Failed to load followers');
  }





  static Future<List<dynamic>> getFollowing({
    required String token,
    required int userId,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/following'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final handled = _handleResponse(response); // ✅ auto logout included

    if (handled is List) return handled;
    if (handled is Map && handled['success'] == false) {
      throw Exception(handled['message'] ?? 'Failed to load following');
    }

    throw Exception('Failed to load following');
  }



  static Future<Map<String, dynamic>> sendOtp({required String phone, required String verificationMethod}) async {
    final uri = Uri.parse('$baseUrl/auth/send-otp');

    debugPrint('📤 OTP REQUEST');
    debugPrint('📞 phone: $phone');
    debugPrint('📝 verificationMethod: $verificationMethod');
    debugPrint('🌍 url: $uri');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json','x-app-type': 'player'},
      body: jsonEncode({'phone': phone, 'verification_method': verificationMethod}),
    );

    debugPrint('📥 OTP REQUEST STATUS: ${response.statusCode}');
    debugPrint('📥 OTP REQUEST BODY: ${response.body}');

    final handled = _handleResponse(response,);

    if (handled is Map<String, dynamic>) return handled;

    return {'success': false, 'message': 'OTP_REQUEST_FAILED', 'statusCode': response.statusCode};
  }

  static Future<Map<String, dynamic>> verifyOtp({required String phone, required String otp}) async {
    final uri = Uri.parse('$baseUrl/auth/verify-otp');

    debugPrint('📤 OTP VERIFY REQUEST');
    debugPrint('📞 phone: $phone');
    debugPrint('🔢 otp: $otp');
    debugPrint('🌍 url: $uri');

    final response = await http.post(uri,headers: {'Content-Type': 'application/json','x-app-type': 'player'}, body: jsonEncode({'phone': phone, 'otp_code': otp}));

    debugPrint('📥 OTP VERIFY STATUS: ${response.statusCode}');
    debugPrint('📥 OTP VERIFY BODY: ${response.body}');

    final handled = _handleResponse(response, );

    if (handled is Map<String, dynamic>) return handled;

    return {'success': false, 'message': 'OTP_VERIFY_FAILED', 'statusCode': response.statusCode};
  }


  static Future<Map<String, dynamic>> hideComment({
    required String token,
    required int commentId,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/comments/$commentId/hide'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({}), // optional
      );

      final handled = _handleResponse(response);
      if (handled is Map && handled['success'] == false) {
        throw Exception(handled['message'] ?? 'Failed to hide comment');
      }
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> sendPasswordResetOtp({
    required String phone,
    required String verificationMethod,
  }) async {
    try {
      // ✅ Preferred endpoint (create it in backend)
      final uri = Uri.parse('$baseUrl/auth/password-reset/request');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'x-app-type': 'player'},
        body: jsonEncode({
          'phone': phone,
          'verification_method': verificationMethod,
        }),
      );

      final handled = _handleResponse(response, autoLogout: false);
      if (handled is Map<String, dynamic>) return handled;

      // fallback map
      return {'success': false, 'message': 'RESET_OTP_REQUEST_FAILED', 'statusCode': response.statusCode};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  static Future<Map<String, dynamic>> resetPasswordWithOtp({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/password-reset/confirm');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'x-app-type': 'player'},
        body: jsonEncode({
          'phone': phone,
          'otp_code': otp,
          'new_password': newPassword,
        }),
      );

      final handled = _handleResponse(response, autoLogout: false);
      if (handled is Map<String, dynamic>) return handled;

      return {'success': false, 'message': 'RESET_PASSWORD_FAILED', 'statusCode': response.statusCode};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }


  static Future<Map<String, dynamic>> unhideComment({
    required String token,
    required int commentId,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/comments/$commentId/unhide'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({}),
      );

      final handled = _handleResponse(response);
      if (handled is Map && handled['success'] == false) {
        throw Exception(handled['message'] ?? 'Failed to unhide comment');
      }
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }



  // Search users by name or position - FIXED VERSION
  static Future<List<User>> searchUsers({
    required String token,
    required String query,
  }) async {
    final url = Uri.parse('$baseUrl/users/search?q=${Uri.encodeComponent(query)}');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final handled = _handleResponse(response);

    if (handled is List) {
      return handled.map((json) => User.fromJson(json)).toList();
    }

    if (handled is Map && handled['success'] == false) {
      throw Exception(handled['message'] ?? 'Failed to search users');
    }

    throw Exception('Failed to search users');
  }


  static Future<Map<String, dynamic>> getUserById({
    required String token,
    required int userId,
  }) async {
    final res = await http.get(
      Uri.parse('$baseUrl/users/$userId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load user (${res.statusCode})');
  }

  static Future<Map<String, dynamic>> getUserStats({
    required String token,
    required int userId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/stats' ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateUserProfile({
    required String token,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/auth/profile' ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> uploadProfilePhoto({
    required String token,
    required String imagePath,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/auth/upload-avatar' ),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('avatar', imagePath ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> uploadAvatar({
    required String token,
    required String imagePath,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/auth/upload-avatar'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('avatar', imagePath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Chat endpoints
  static Future<dynamic> getChats(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chats'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> createChat({
    required String token,
    required int userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chats'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'user_id': userId,
        }),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> startChat({
    required String token,
    required int otherUserId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chats/start'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'other_user_id': otherUserId,
        }),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> sendMessage({
    required String token,
    required int chatId,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chats/$chatId/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'message': message,
        }),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<dynamic> getMessages({
    required String token,
    required int chatId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chats/$chatId/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteChat({
    required String token,
    required int chatId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/chats/$chatId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteMessage({
    required String token,
    required int messageId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/messages/$messageId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> editMessage({
    required String token,
    required int messageId,
    required String newMessage,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/messages/$messageId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'new_message': newMessage,
        }),
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> pinMessage({
    required String token,
    required int messageId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/messages/$messageId/pin'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ============================================
  // COMMENT SYSTEM ENDPOINTS - NEW
  // ============================================

  /// Get all comments for a specific post
  static Future<dynamic> getComments({
    required String token,
    required int postId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/comments/$postId'), // ✅ FIX
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }



  /// Add a new comment to a post
  static Future<dynamic> addComment({
    required String token,
    required int postId,
    required String content,
    int? parentCommentId,
  }) async {
    final body = {
      'comment_text': content.trim(),
      if (parentCommentId != null) 'parent_comment_id': parentCommentId,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/comments/$postId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    return jsonDecode(response.body);
  }

  /// Delete a comment (only owner can delete)
  static Future<Map<String, dynamic>> deleteComment({
    required String token,
    required int commentId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/comments/$commentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ============================================
  // NOTIFICATION SYSTEM ENDPOINTS - NEW
  // ============================================

  static Future<Map<String, dynamic>> getNotifications(String token, {int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications?page=$page'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> markNotificationAsRead(String token, int notificationId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/notifications/$notificationId/read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> markAllNotificationsAsRead(String token) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/notifications/read-all'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteNotification(String token, int notificationId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/notifications/$notificationId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getUnreadNotificationCount(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications/unread-count'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // View Count endpoint
  static Future<void> incrementPostView(int postId) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/posts/$postId/view'),
      );
    } catch (e) {
      print('Error incrementing view: $e');
    }
  }

  // Statistics endpoints
  static Future<Map<String, dynamic>> getUserStatistics({
    required String token,
    required int userId,
    String? period,
  }) async {
    try {
      String url = '$baseUrl/users/$userId/statistics';
      if (period != null) {
        url += '?period=$period';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Helper method to handle responses

  static dynamic _handleResponse(
      http.Response response, {
        bool autoLogout = true,
      }) {
    debugPrint('API Response [${response.statusCode}]: ${response.body}');

    // ✅ AUTO LOGOUT only when this request requires a token
    if (autoLogout && response.statusCode == 401) {
      SessionHandler.forceLogout('Session expired. Please sign in again.');
      // IMPORTANT: do NOT throw "Unauthorized" because you lose backend message
      return {
        'success': false,
        'message': 'Session expired. Please sign in again.',
        'statusCode': 401,
      };
    }

    // ✅ SUCCESS
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.trim().isEmpty) return null;
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return response.body;
      }
    }

    // ✅ ERROR: return backend message (do NOT throw)
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map) {
        return {
          'success': false,
          'message': decoded['message'] ?? decoded['error'] ?? 'An error occurred',
          'statusCode': response.statusCode,
          'raw': decoded,
        };
      }

      return {
        'success': false,
        'message': decoded.toString(),
        'statusCode': response.statusCode,
        'raw': decoded,
      };
    } catch (_) {
      return {
        'success': false,
        'message': response.body.isNotEmpty
            ? response.body
            : 'Request failed: ${response.statusCode}',
        'statusCode': response.statusCode,
      };
    }
  }



}
