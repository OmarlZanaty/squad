import 'package:flutter/material.dart';

class AppColors {
  // Theme-aware color getters
  static Color getBackground(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  static Color getSurface(BuildContext context) {
    return Theme.of(context).cardTheme.color ?? surface;
  }

  static Color getTextPrimary(BuildContext context) {
    return Theme.of(context).textTheme.bodyLarge?.color ?? textPrimary;
  }

  static Color getTextSecondary(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium?.color ?? textSecondary;
  }

  // Primary Colors - Teal Theme
  static const Color primary = Color(0xFF26A69A);  // Teal
  static const Color primaryDark = Color(0xFF00897B);
  static const Color primaryLight = Color(0xFF4DB6AC);
  static const Color primaryVeryLight = Color(0xFFE0F2F1);

  // Accent Colors
  static const Color secondary = Color(0xFF26A69A);  // Teal
  static const Color accentGold = Color(0xFFFFD700);  // For VIP sections
  static const Color accentOrange = Color(0xFFFF9800);  // For new items
  static const Color accent = Color(0xFFF39C12);  // Keep for compatibility

  // Dark Mode Accent Colors - TEAL/CYAN
  static const Color darkAccent = Color(0xFF38DBBE);  // Teal color #38dbbe
  static const Color darkAccentDark = Color(0xFF2BC9A8);  // Slightly darker variant
  static const Color darkModeAccent = Color(0xFF38DBBE);  // Alias for backward compatibility

  // Background Colors
  static const Color background = Color(0xFFF5F7FA);
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color backgroundDark = Color(0xFF1A1F2E);  // Dark navy background
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF5F5F5);

  // Text Colors
  static const Color text = Color(0xFF1A1A1A);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Neutral Colors
  static const Color black = Color(0xFF1A1A1A);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFF757575);
  static const Color greyLight = Color(0xFFE0E0E0);
  static const Color greyDark = Color(0xFF424242);

  // Status Colors
  static const Color success = Color(0xFF26A69A);
  static const Color error = Color(0xFFF44336);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);

  // Card Colors (for player cards)
  static const Color cardDark = Color(0xFF252B3B);  // Darker cards for dark mode
  static const Color cardDarkSecondary = Color(0xFF2A3142);  // Secondary card color
  static const Color secondaryCardDark = Color(0xFF2A3142);  // Alias for backward compatibility

  // Border Colors
  static const Color border = Color(0xFFE0E0E0);  // Light mode border
  static const Color borderDark = Color(0xFF2A3142);  // Dark mode border

  // Shadow Colors
  static const Color shadow = Color(0x1A000000);
  static const Color shadowDark = Color(0x3A000000);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF26A69A), Color(0xFF00897B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF2C3E50), Color(0xFF34495E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Dark Mode Gradient - TEAL COLOR
  static const LinearGradient darkAccentGradient = LinearGradient(
    colors: [Color(0xFF38DBBE), Color(0xFF2BC9A8)],  // Teal gradient
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Theme Data
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: accentOrange,
        surface: surface,
        background: background,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: white,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: greyLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: greyLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
      ),
      fontFamily: 'Cairo',
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: darkAccent,
        primary: darkAccent,
        secondary: darkAccentDark,
        surface: cardDark,
        background: backgroundDark,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: backgroundDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: cardDark,
        foregroundColor: white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkAccent,
          foregroundColor: black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: darkAccent, width: 2),
        ),
      ),
      fontFamily: 'Cairo',
    );
  }
}
