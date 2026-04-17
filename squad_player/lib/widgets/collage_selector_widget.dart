import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CollageSelectorWidget extends StatefulWidget {
  final Function(List<File>, String) onCollageSelected;

  const CollageSelectorWidget({
    Key? key,
    required this.onCollageSelected,
  }) : super(key: key);

  @override
  State<CollageSelectorWidget> createState() => _CollageSelectorWidgetState();
}

class _CollageSelectorWidgetState extends State<CollageSelectorWidget> {
  final ImagePicker _imagePicker = ImagePicker();
  List<File> _selectedImages = [];
  String _collageLayout = '2x2'; // 2x2, 3x3, 1x2, 2x1

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        setState(() {
          _selectedImages = images.map((img) => File(img.path)).toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking images: $e')),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _confirmCollage() {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 2 images')),
      );
      return;
    }

    widget.onCollageSelected(_selectedImages, _collageLayout);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Create Image Collage',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),

        // Layout selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Layout:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildLayoutButton('2x2', '4 images'),
                  _buildLayoutButton('3x3', '9 images'),
                  _buildLayoutButton('1x2', '2 images'),
                  _buildLayoutButton('2x1', '2 images'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Pick images button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: ElevatedButton.icon(
            onPressed: _pickImages,
            icon: const Icon(Icons.add_photo_alternate),
            label: Text(
              _selectedImages.isEmpty
                  ? 'Pick Images'
                  : 'Pick More (${_selectedImages.length})',
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Selected images preview
        if (_selectedImages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected Images (${_selectedImages.length}):',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _selectedImages[index],
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 24),

        // Confirm button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: ElevatedButton(
            onPressed: _selectedImages.isEmpty ? null : _confirmCollage,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: Colors.blue,
              disabledBackgroundColor: Colors.grey,
            ),
            child: const Text(
              'Create Collage',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildLayoutButton(String layout, String description) {
    final isSelected = _collageLayout == layout;
    return FilterChip(
      label: Text('$layout\n$description'),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _collageLayout = layout;
        });
      },
      backgroundColor: Colors.grey[200],
      selectedColor: Colors.blue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
      ),
    );
  }
}
