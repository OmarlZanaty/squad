/*
import 'package:flutter/material.dart';
import 'package:squad_player/services/api_service.dart';
import 'package:squad_player/services/auth_service.dart';
import 'package:squad_player/utils/app_localizations.dart';
import '../widgets/media_grid_widget.dart';

class MediaLibraryScreen extends StatefulWidget {
  const MediaLibraryScreen({Key? key}) : super(key: key);

  @override
  State<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends State<MediaLibraryScreen> {
  List<Map<String, dynamic>> _mediaList = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _filterType = 'all'; // all, images, videos

  @override
  void initState() {
    super.initState();
    _loadMediaLibrary();
  }

  Future<void> _loadMediaLibrary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    */
/*try {
      final token = await AuthService.getToken();
      if (token == null) {
        setState(() {
          _errorMessage = 'Not authenticated';
          _isLoading = false;
        });
        return;
      }*//*


      // Call API to get media library
      //final response = await ApiService.getMediaLibrary(token: token);

      */
/*if (response is List) {
        setState(() {
          _mediaList = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      } else if (response is Map && response['message'] != null) {
        setState(() {
          _errorMessage = response['message'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading media: $e';
        _isLoading = false;
      });*//*

    }
  }

  List<Map<String, dynamic>> get _filteredMedia {
    if (_filterType == 'all') return _mediaList;
    if (_filterType == 'images') {
      return _mediaList.where((m) => m['type'] == 'image').toList();
    }
    return _mediaList.where((m) => m['type'] == 'video').toList();
  }

  Future<void> _deleteMedia(int mediaId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Media'),
        content: const Text('Are you sure you want to delete this media?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final token = await AuthService.getToken();
        if (token != null) {
          //await ApiService.deleteMedia(mediaId: mediaId, token: token);
          _loadMediaLibrary();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Media deleted successfully')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting media: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc?.tr('media_library') ?? 'Media Library'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                _buildFilterButton('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterButton('Images', 'images'),
                const SizedBox(width: 8),
                _buildFilterButton('Videos', 'videos'),
              ],
            ),
          ),

          // Media count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              '${_filteredMedia.length} ${_filterType == 'all' ? 'items' : _filterType}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),

          // Media grid or loading/error
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(_errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadMediaLibrary,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
                : _filteredMedia.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_not_supported_outlined,
                      size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(loc?.tr('no_media') ?? 'No media found'),
                ],
              ),
            )
                : MediaGridWidget(
              mediaList: _filteredMedia,
              onDelete: _deleteMedia,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, String type) {
    final isActive = _filterType == type;
    return Expanded(
      child: ElevatedButton(
        onPressed: () => setState(() => _filterType = type),
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? Colors.blue : Colors.grey[300],
          foregroundColor: isActive ? Colors.white : Colors.black,
        ),
        child: Text(label),
      ),
    );
  }
}
*/
