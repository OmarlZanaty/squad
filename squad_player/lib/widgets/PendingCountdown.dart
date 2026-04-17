import 'dart:async';
import 'package:flutter/material.dart';

class PendingCountdown extends StatefulWidget {
  final DateTime createdAt;
  final Duration duration;

  const PendingCountdown({
    super.key,
    required this.createdAt,
    this.duration = const Duration(hours: 24),
  });

  @override
  State<PendingCountdown> createState() => _PendingCountdownState();
}

class _PendingCountdownState extends State<PendingCountdown> {
  Timer? _timer;
  Duration _remaining = Duration.zero; // ✅ NO late

  @override
  void initState() {
    super.initState();

    _calculateRemaining();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
          (_) => _calculateRemaining(),
    );
  }

  void _calculateRemaining() {
    final createdUtc = widget.createdAt.toUtc();
    final endTime = createdUtc.add(widget.duration);
    final nowUtc = DateTime.now().toUtc();

    final diff = endTime.difference(nowUtc);

    if (diff.isNegative) {
      _remaining = Duration.zero;
      _timer?.cancel(); // ✅ SAFE
    } else {
      _remaining = diff;
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _timer?.cancel(); // ✅ SAFE
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining == Duration.zero) {
      return const SizedBox.shrink();
    }

    final hours = _remaining.inHours;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.timer, size: 12, color: Colors.orange),
        const SizedBox(width: 4),
        Text(
          '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
          style: const TextStyle(
            fontSize: 11,
            color: Colors.orange,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );


  }
}
