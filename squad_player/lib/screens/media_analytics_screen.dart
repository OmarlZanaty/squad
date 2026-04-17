import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/app_colors.dart';
import '../services/api_service.dart';
import 'package:squad_player/utils/app_localizations.dart';

class MediaAnalyticsScreen extends StatefulWidget {
  final int mediaId;
  const MediaAnalyticsScreen({required this.mediaId, super.key});

  @override
  State<MediaAnalyticsScreen> createState() => _MediaAnalyticsScreenState();
}

class _MediaAnalyticsScreenState extends State<MediaAnalyticsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _analytics;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        setState(() => _error = 'Not authenticated');
        return;
      }

      final response = await http.get(
        Uri.parse('http://187.124.37.68:3000/api/media/${widget.mediaId}/analytics'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _analytics = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _error = 'Failed to load analytics');
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('Media Analytics'),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _loadAnalytics,
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAnalyticsCard(
                            icon: Icons.visibility,
                            title: 'Views',
                            value: '${_analytics?['views'] ?? 0}',
                            color: Colors.blue,
                            isDark: isDark,
                          ),
                          SizedBox(height: 12),
                          _buildAnalyticsCard(
                            icon: Icons.favorite,
                            title: 'Likes',
                            value: '${_analytics?['likes'] ?? 0}',
                            color: Colors.red,
                            isDark: isDark,
                          ),
                          SizedBox(height: 12),
                          _buildAnalyticsCard(
                            icon: Icons.comment,
                            title: 'Comments',
                            value: '${_analytics?['comments'] ?? 0}',
                            color: Colors.green,
                            isDark: isDark,
                          ),
                          SizedBox(height: 12),
                          _buildAnalyticsCard(
                            icon: Icons.share,
                            title: 'Shares',
                            value: '${_analytics?['shares'] ?? 0}',
                            color: Colors.orange,
                            isDark: isDark,
                          ),
                          SizedBox(height: 20),
                          if (_analytics?['watch_time'] != null)
                            _buildAnalyticsCard(
                              icon: Icons.timer,
                              title: 'Watch Time',
                              value: '${_analytics?['watch_time']} min',
                              color: Colors.purple,
                              isDark: isDark,
                            ),
                          SizedBox(height: 20),
                          _buildEngagementRate(isDark),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildAnalyticsCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
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

  Widget _buildEngagementRate(bool isDark) {
    final views = _analytics?['views'] ?? 1;
    final engagements = (_analytics?['likes'] ?? 0) + (_analytics?['comments'] ?? 0) + (_analytics?['shares'] ?? 0);
    final rate = ((engagements / views) * 100).toStringAsFixed(2);

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Engagement Rate',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          SizedBox(height: 12),
          LinearProgressIndicator(
            value: double.parse(rate) / 100,
            minHeight: 8,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation(Colors.green),
          ),
          SizedBox(height: 8),
          Text(
            '$rate%',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}
