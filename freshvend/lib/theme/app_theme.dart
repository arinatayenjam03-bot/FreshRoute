// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static const Color primary       = Color(0xFF1A1A1A);
  static const Color accent        = Color(0xFF00A651);
  static const Color accentLight   = Color(0xFFE8F5EE);
  static const Color gold          = Color(0xFFFFB800);
  static const Color goldLight     = Color(0xFFFFF8E1);
  static const Color background    = Color(0xFFF7F7F7);
  static const Color surface       = Color(0xFFFFFFFF);
  static const Color surfaceGrey   = Color(0xFFF2F2F2);
  static const Color divider       = Color(0xFFEEEEEE);
  static const Color textPrimary   = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textMuted     = Color(0xFFBDBDBD);
  static const Color success       = Color(0xFF00A651);
  static const Color warning       = Color(0xFFFFB800);
  static const Color danger        = Color(0xFFE53935);
  static const Color info          = Color(0xFF1976D2);
  static const Color navBg         = Color(0xFF000000);
  static const Color navSelected   = Color(0xFFFFFFFF);
  static const Color navUnselected = Color(0xFF757575);

  static ThemeData get light => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: background,
    primaryColor: primary,
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: accent,
      surface: surface,
      onPrimary: Colors.white,
      onSurface: textPrimary,
      error: danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      iconTheme: IconThemeData(color: textPrimary),
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: const CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: divider, width: 1),
      ),
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        minimumSize: const Size(double.infinity, 52),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceGrey,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
      hintStyle: const TextStyle(color: textMuted, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    dividerTheme: const DividerThemeData(color: divider, thickness: 1, space: 0),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: navBg,
      selectedItemColor: navSelected,
      unselectedItemColor: navUnselected,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 11),
    ),
  );
}

class AppConstants {
  static const String baseUrl              = 'http://192.168.137.1:8000';
  static const double avgPetrolPriceIndia  = 102.0;
  static const double avgFuelEfficiency    = 18.0;
  // Image asset paths — drop your files into assets/images/ folder
  static const String logoPath            = 'assets/images/logo.png';
  static const String heroBannerPath      = 'assets/images/hero_banner.jpg';
}