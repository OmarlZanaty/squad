import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/app_localizations.dart';

class AdjustImagePositionResult {
  final double focusX; // -1..1
  final double focusY; // -1..1
  const AdjustImagePositionResult({required this.focusX, required this.focusY});
}

class AdjustImagePositionScreen extends StatefulWidget {
  final File imageFile;
  final double aspectRatio; // cover: 16/9 or 3/1 etc
  final bool isCircle; // for profile preview
  final String title;

  final double initialFocusX;
  final double initialFocusY;

  const AdjustImagePositionScreen({
    super.key,
    required this.imageFile,
    required this.aspectRatio,
    required this.isCircle,
    required this.title,
    this.initialFocusX = 0,
    this.initialFocusY = 0,
  });

  @override
  State<AdjustImagePositionScreen> createState() =>
      _AdjustImagePositionScreenState();
}

class _AdjustImagePositionScreenState extends State<AdjustImagePositionScreen> {
  late double _x;
  late double _y;

  Offset? _lastPos;

  String _t(BuildContext context, String key, String fallback) {
    final tr = AppLocalizations.of(context);
    return tr?.tr(key) ?? fallback;
  }

  @override
  void initState() {
    super.initState();
    _x = widget.initialFocusX.clamp(-1.0, 1.0);
    _y = widget.initialFocusY.clamp(-1.0, 1.0);
  }

  void _applyDelta(Offset delta, Size box) {
    // Convert pixels -> alignment delta (-1..1)
    final dx = delta.dx / (box.width * 0.55);
    final dy = delta.dy / (box.height * 0.55);

    setState(() {
      // ✅ FIX REVERSE:
      // With BoxFit.cover, moving the finger right/down often needs NEGATIVE alignment delta
      // to "move the visible area" the same direction as your finger.
      _x = (_x - dx).clamp(-1.0, 1.0);
      _y = (_y - dy).clamp(-1.0, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hintText = _t(context, 'drag_to_adjust', 'Drag to adjust');
    final doneText = _t(context, 'done', 'Done');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(
                context,
                AdjustImagePositionResult(focusX: _x, focusY: _y),
              );
            },
            child: Text(doneText),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AspectRatio(
            aspectRatio: widget.aspectRatio,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final box = Size(constraints.maxWidth, constraints.maxHeight);

                Widget image = Image.file(
                  widget.imageFile,
                  fit: BoxFit.cover,
                  alignment: Alignment(_x, _y),
                );

                image = widget.isCircle
                    ? ClipOval(child: image)
                    : ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: image,
                );

                return Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) => _lastPos = e.position,
                  onPointerUp: (_) => _lastPos = null,
                  onPointerCancel: (_) => _lastPos = null,
                  onPointerMove: (e) {
                    if (_lastPos == null) {
                      _lastPos = e.position;
                      return;
                    }
                    final delta = e.position - _lastPos!;
                    _lastPos = e.position;
                    _applyDelta(delta, box);
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      image,

                      IgnorePointer(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.45),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$hintText   (x:${_x.toStringAsFixed(2)} y:${_y.toStringAsFixed(2)})',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
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
        ),
      ),
    );
  }
}