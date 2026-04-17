import 'package:flutter/material.dart';

class UploadProgressWidget extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final String fileName;
  final String? fileSize;
  final bool isUploading;
  final bool isCompleted;
  final bool hasError;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;

  const UploadProgressWidget({
    Key? key,
    required this.progress,
    required this.fileName,
    this.fileSize,
    this.isUploading = true,
    this.isCompleted = false,
    this.hasError = false,
    this.errorMessage,
    this.onRetry,
    this.onCancel,
  }) : super(key: key);

  @override
  State<UploadProgressWidget> createState() => _UploadProgressWidgetState();
}

class _UploadProgressWidgetState extends State<UploadProgressWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    if (widget.isUploading && !widget.isCompleted) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(UploadProgressWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isCompleted && oldWidget.isUploading) {
      _animationController.stop();
    } else if (widget.isUploading && !widget.isCompleted) {
      _animationController.repeat();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _formatProgress() {
    return '${(widget.progress * 100).toStringAsFixed(0)}%';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with file name and status
            Row(
              children: [
                // Status icon
                if (widget.hasError)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.error, color: Colors.red[700]),
                  )
                else if (widget.isCompleted)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.check_circle, color: Colors.green[700]),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: RotationTransition(
                      turns: _animationController,
                      child: Icon(Icons.cloud_upload, color: Colors.blue[700]),
                    ),
                  ),
                const SizedBox(width: 12),
                // File name and size
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.fileName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.fileSize != null)
                        Text(
                          widget.fileSize!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                    ],
                  ),
                ),
                // Progress percentage
                Text(
                  _formatProgress(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: widget.hasError ? Colors.red : Colors.blue,
                      ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: widget.progress,
                minHeight: 8,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  widget.hasError
                      ? Colors.red
                      : widget.isCompleted
                          ? Colors.green
                          : Colors.blue,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Status message
            if (widget.hasError && widget.errorMessage != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red[200]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red[700], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.errorMessage!,
                        style: TextStyle(color: Colors.red[700], fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )
            else if (widget.isCompleted)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  border: Border.all(color: Colors.green[200]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700], size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Upload completed successfully',
                      style: TextStyle(color: Colors.green[700], fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              Text(
                widget.isUploading ? 'Uploading...' : 'Pending',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),

            const SizedBox(height: 12),

            // Action buttons
            if (widget.hasError || widget.isUploading)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.onCancel != null)
                    TextButton.icon(
                      onPressed: widget.onCancel,
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                      ),
                    ),
                  if (widget.hasError && widget.onRetry != null)
                    SizedBox(
                      width: 8,
                    ),
                  if (widget.hasError && widget.onRetry != null)
                    ElevatedButton.icon(
                      onPressed: widget.onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Multiple uploads progress list
class UploadProgressListWidget extends StatelessWidget {
  final List<Map<String, dynamic>> uploads;
  final Function(int) onRetry;
  final Function(int) onCancel;

  const UploadProgressListWidget({
    Key? key,
    required this.uploads,
    required this.onRetry,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: uploads.length,
      itemBuilder: (context, index) {
        final upload = uploads[index];
        return UploadProgressWidget(
          progress: upload['progress'] ?? 0.0,
          fileName: upload['fileName'] ?? 'Unknown',
          fileSize: upload['fileSize'],
          isUploading: upload['isUploading'] ?? false,
          isCompleted: upload['isCompleted'] ?? false,
          hasError: upload['hasError'] ?? false,
          errorMessage: upload['errorMessage'],
          onRetry: () => onRetry(index),
          onCancel: () => onCancel(index),
        );
      },
    );
  }
}
