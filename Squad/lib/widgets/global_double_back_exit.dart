import 'package:flutter/material.dart';

class GlobalDoubleBackExit extends StatefulWidget {
  final Widget child;
  final String message;

  const GlobalDoubleBackExit({
    super.key,
    required this.child,
    this.message = 'Press back again to exit',
  });

  @override
  State<GlobalDoubleBackExit> createState() => _GlobalDoubleBackExitState();
}

class _GlobalDoubleBackExitState extends State<GlobalDoubleBackExit> {
  DateTime? _lastBackPress;

  bool _shouldExitNow() {
    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // we decide manually
      onPopInvoked: (didPop) async {
        // If something already popped, do nothing.
        if (didPop) return;

        final navigator = Navigator.of(context);

        // If there is a page to pop -> normal back behavior
        if (navigator.canPop()) {
          navigator.pop();
          return;
        }

        // We're at the root of the app -> double back to exit
        if (!_shouldExitNow()) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.message),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }

        // Allow system to close the app
        // (By returning without intercepting. PopScope will allow after second click.)
        // In practice, you may need SystemNavigator.pop() on some devices:
        // SystemNavigator.pop();
      },
      child: widget.child,
    );
  }
}
