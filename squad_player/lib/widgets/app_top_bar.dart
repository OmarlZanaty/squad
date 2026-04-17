import 'package:flutter/material.dart';
import 'package:squad_player/utils/app_colors.dart';

import '../utils/app_colors.dart';

/// Universal Top Bar Widget
/// A reusable app bar that can be used across all screens
/// Features:
/// - Optional back button
/// - Center logo or custom title
/// - Optional action buttons
/// - Consistent styling with shadow
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showBackButton;
  final bool showLogo;
  final String? title;
  final List<Widget>? actions;
  final VoidCallback? onBackPressed;
  final double height;

  const AppTopBar({
    Key? key,
    this.showBackButton = true,
    this.showLogo = true,
    this.title,
    this.actions,
    this.onBackPressed,
    this.height = 70.0,
  }) : super(key: key);

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: isDark ? AppColors.shadowDark : AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Side - Back Button or Empty Space
          SizedBox(
            width: 48,
            child: showBackButton
                ? IconButton(
              icon: Icon(
                Icons.arrow_back,
                size: 28,
                color: isDark ? Colors.white : AppColors.black,
              ),
              onPressed: onBackPressed ?? () => Navigator.pop(context),
              padding: EdgeInsets.zero,
            )
                : const SizedBox.shrink(),
          ),

          // Center - Logo or Title
          Expanded(
            child: Center(
              child: showLogo
                  ? Image.asset(
                'assets/images/logo3.png',
                height: 50,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback if logo not found
                  return Text(
                    'SQUAD',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      //color: isDark ? AppColors.darkModeAccent : AppColors.primary,
                    ),
                  );
                },
              )
                  : title != null
                  ? Text(
                title!,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.black,
                ),
              )
                  : const SizedBox.shrink(),
            ),
          ),

          // Right Side - Actions or Empty Space
          actions != null && actions!.isNotEmpty
              ? Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: actions!,
          )
              : const SizedBox(width: 48),
        ],
      ),
    );
  }
}
