import 'package:flutter/material.dart';

class DoubleBackExit extends StatefulWidget {
  final Widget child;
  final String message;

  const DoubleBackExit({
    super.key,
    required this.child,
    this.message = 'Press back again to exit',
  });

  @override
  State<DoubleBackExit> createState() => _DoubleBackExitState();
}

class _DoubleBackExitState extends State<DoubleBackExit> {
  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final now = DateTime.now();

        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.message),
              duration: const Duration(seconds: 2),
            ),
          );

          return false; // ❌ don't exit
        }

        return true; // ✅ exit app
      },
      child: widget.child,
    );
  }
}
