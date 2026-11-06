import 'package:flutter/material.dart';

class AppColors {
  /// Brand purple — Material Deep Purple 400.
  static const Color primary = Color(0xFF7E57C2);
  /// Lighter purple for gradients, info, and highlights.
  static const Color primaryLight = Color(0xFFB39DDB);
  /// Darker purple for trade accents and pressed states.
  static const Color primaryDark = Color(0xFF5E35B1);
  /// Deep purple for strong emphasis.
  static const Color primaryDeep = Color(0xFF4527A0);
  /// Mid purple for secondary accents (replaces blue-grey tints).
  static const Color primaryMuted = Color(0xFF9575CD);
  /// Soft purple surface (cards, chips).
  static const Color primarySurface = Color(0xFFEDE7F6);
  /// Very light purple page tint (replaces blue-tinted whites).
  static const Color primaryTintSoft = Color(0xFFF8F5FF);

  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF1C1B1F);
  static const Color lightTextSecondary = Color(0xFF4B4A4F);

  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkTextPrimary = Color(0xFFE3E3E3);
  static const Color darkTextSecondary = Color(0xFFB3B3B3);

  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);
  static const Color info = AppColors.primaryMuted;
}

class AppTheme {
  static Color get primaryColor => AppColors.primary;
  /// Module accents — trade/community use purple shades for brand consistency.
  static const Color tradeColor = AppColors.primaryDark;
  static const Color giftColor = Color(0xFF9333EA);
  static const Color donationColor = Color(0xFF059669);
  static const Color karmaColor = Color(0xFFF59E0B);
  static const Color communityColor = AppColors.primaryLight;
  static const Color successColor = AppColors.success;
  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    final scheme = base.colorScheme.copyWith(
      primary: AppColors.primary,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      onSurfaceVariant: AppColors.lightTextSecondary,
      outline: const Color(0xFFE0E0E0),
      error: AppColors.error,
    );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightSurface,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      textTheme: _buildTextTheme(AppColors.lightTextPrimary, AppColors.lightTextSecondary),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    final scheme = base.colorScheme.copyWith(
      primary: AppColors.primary,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      onSurfaceVariant: AppColors.darkTextSecondary,
      outline: const Color(0xFF3A3A3A),
      error: AppColors.error,
    );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      textTheme: _buildTextTheme(AppColors.darkTextPrimary, AppColors.darkTextSecondary),
    );
  }

  static BoxDecoration glassDecoration({required bool isDark}) {
    return BoxDecoration(
      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static TextTheme _buildTextTheme(Color textColor, Color secondaryColor) {
    return TextTheme(
      displayLarge: TextStyle(color: textColor, fontSize: 32, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
      headlineLarge: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.w600),
      headlineMedium: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(color: secondaryColor, fontSize: 12, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: textColor, fontSize: 16),
      bodyMedium: TextStyle(color: textColor, fontSize: 14),
      bodySmall: TextStyle(color: secondaryColor, fontSize: 12),
      labelLarge: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(color: secondaryColor, fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(color: secondaryColor, fontSize: 10, fontWeight: FontWeight.w500),
    );
  }
}
