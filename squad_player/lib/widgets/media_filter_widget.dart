import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class MediaFilterWidget extends StatefulWidget {
  final Function(MediaFilter) onFilterChanged;
  final bool isDark;

  const MediaFilterWidget({
    required this.onFilterChanged,
    required this.isDark,
    super.key,
  });

  @override
  State<MediaFilterWidget> createState() => _MediaFilterWidgetState();
}

class _MediaFilterWidgetState extends State<MediaFilterWidget> {
  late MediaFilter _filter;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filter = MediaFilter();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateFilter() {
    _filter.searchQuery = _searchController.text;
    widget.onFilterChanged(_filter);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.cardDark : Colors.white,
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
          // Search field
          TextField(
            controller: _searchController,
            onChanged: (_) => _updateFilter(),
            decoration: InputDecoration(
              hintText: 'Search media...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          SizedBox(height: 16),

          // Type filter
          Text(
            'Type',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: widget.isDark ? Colors.white : Colors.black,
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildFilterChip(
                label: 'All',
                selected: _filter.type == null,
                onSelected: () {
                  setState(() => _filter.type = null);
                  _updateFilter();
                },
              ),
              _buildFilterChip(
                label: 'Images',
                selected: _filter.type == 'image',
                onSelected: () {
                  setState(() => _filter.type = 'image');
                  _updateFilter();
                },
              ),
              _buildFilterChip(
                label: 'Videos',
                selected: _filter.type == 'video',
                onSelected: () {
                  setState(() => _filter.type = 'video');
                  _updateFilter();
                },
              ),
            ],
          ),
          SizedBox(height: 16),

          // Size filter
          Text(
            'Size',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: widget.isDark ? Colors.white : Colors.black,
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildFilterChip(
                label: 'All',
                selected: _filter.sizeFilter == null,
                onSelected: () {
                  setState(() => _filter.sizeFilter = null);
                  _updateFilter();
                },
              ),
              _buildFilterChip(
                label: 'Small (<5MB)',
                selected: _filter.sizeFilter == 'small',
                onSelected: () {
                  setState(() => _filter.sizeFilter = 'small');
                  _updateFilter();
                },
              ),
              _buildFilterChip(
                label: 'Medium (5-50MB)',
                selected: _filter.sizeFilter == 'medium',
                onSelected: () {
                  setState(() => _filter.sizeFilter = 'medium');
                  _updateFilter();
                },
              ),
              _buildFilterChip(
                label: 'Large (>50MB)',
                selected: _filter.sizeFilter == 'large',
                onSelected: () {
                  setState(() => _filter.sizeFilter = 'large');
                  _updateFilter();
                },
              ),
            ],
          ),
          SizedBox(height: 16),

          // Sort options
          Text(
            'Sort By',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: widget.isDark ? Colors.white : Colors.black,
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildFilterChip(
                label: 'Newest',
                selected: _filter.sortBy == 'newest',
                onSelected: () {
                  setState(() => _filter.sortBy = 'newest');
                  _updateFilter();
                },
              ),
              _buildFilterChip(
                label: 'Oldest',
                selected: _filter.sortBy == 'oldest',
                onSelected: () {
                  setState(() => _filter.sortBy = 'oldest');
                  _updateFilter();
                },
              ),
              _buildFilterChip(
                label: 'Name (A-Z)',
                selected: _filter.sortBy == 'name',
                onSelected: () {
                  setState(() => _filter.sortBy = 'name');
                  _updateFilter();
                },
              ),
              _buildFilterChip(
                label: 'Size (Large)',
                selected: _filter.sortBy == 'size',
                onSelected: () {
                  setState(() => _filter.sortBy = 'size');
                  _updateFilter();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      backgroundColor: widget.isDark ? Colors.grey[800] : Colors.grey[200],
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : (widget.isDark ? Colors.white : Colors.black),
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

class MediaFilter {
  String searchQuery = '';
  String? type; // 'image', 'video', or null for all
  String? sizeFilter; // 'small', 'medium', 'large'
  String sortBy = 'newest'; // 'newest', 'oldest', 'name', 'size'

  bool matches(Map<String, dynamic> media) {
    // Search query match
    if (searchQuery.isNotEmpty) {
      final name = (media['name'] ?? '').toString().toLowerCase();
      if (!name.contains(searchQuery.toLowerCase())) {
        return false;
      }
    }

    // Type match
    if (type != null) {
      final mediaType = media['type'] ?? '';
      if (mediaType != type) {
        return false;
      }
    }

    // Size match
    if (sizeFilter != null) {
      final size = (media['size'] ?? 0) as int;
      final sizeInMB = size / (1024 * 1024);
      
      switch (sizeFilter) {
        case 'small':
          if (sizeInMB > 5) return false;
          break;
        case 'medium':
          if (sizeInMB < 5 || sizeInMB > 50) return false;
          break;
        case 'large':
          if (sizeInMB < 50) return false;
          break;
      }
    }

    return true;
  }

  int compareMedia(Map<String, dynamic> a, Map<String, dynamic> b) {
    switch (sortBy) {
      case 'newest':
        final dateA = DateTime.parse(a['created_at'] ?? '2000-01-01');
        final dateB = DateTime.parse(b['created_at'] ?? '2000-01-01');
        return dateB.compareTo(dateA);
      case 'oldest':
        final dateA = DateTime.parse(a['created_at'] ?? '2000-01-01');
        final dateB = DateTime.parse(b['created_at'] ?? '2000-01-01');
        return dateA.compareTo(dateB);
      case 'name':
        final nameA = (a['name'] ?? '').toString().toLowerCase();
        final nameB = (b['name'] ?? '').toString().toLowerCase();
        return nameA.compareTo(nameB);
      case 'size':
        final sizeA = (a['size'] ?? 0) as int;
        final sizeB = (b['size'] ?? 0) as int;
        return sizeB.compareTo(sizeA);
      default:
        return 0;
    }
  }
}
