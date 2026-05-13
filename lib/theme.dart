import 'package:flutter/material.dart';

/// Central place for all colors, text styles, and theme data.
/// Edit this file to restyle the whole app at once.
class AppTheme {
  // ── Brand colors ──────────────────────────────────────────────
  static const Color primary = Color(0xFF4F46E5);       // indigo
  static const Color primaryForeground = Colors.white;
  static const Color secondary = Color(0xFFF1F5F9);     // slate-100
  static const Color secondaryForeground = Color(0xFF0F172A);
  static const Color muted = Color(0xFFF1F5F9);
  static const Color mutedForeground = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color background = Color(0xFFF8FAFC);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color destructive = Color(0xFFEF4444);

  // ── Accent colors (for member avatars, quests, premium, etc.) ─
  static const Color purple = Color(0xFF0EA5E9);        // sky blue accent
  static const Color green = Color(0xFF16A34A);
  static const Color yellow = Color(0xFFFACC15);

  // ── Gradients ─────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF0EA5E9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Member avatar colors ───────────────────────────────────────
  static const List<Color> memberColors = [
    Color(0xFF3B82F6), // blue  – Alex
    Color(0xFF8B5CF6), // purple – Jordan
    Color(0xFF22C55E), // green  – Sam
    Color(0xFFF97316), // orange – Casey
  ];

  // ── Light theme ───────────────────────────────────────────────
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: background,
        cardTheme: CardThemeData(
          color: cardBackground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: border),
          ),
          margin: EdgeInsets.zero,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: primary, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: primaryForeground,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0F172A),
            side: const BorderSide(color: border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: secondary,
          labelStyle: const TextStyle(fontSize: 12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        dividerTheme: const DividerThemeData(color: border, space: 1),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: background,
          selectedItemColor: primary,
          unselectedItemColor: mutedForeground,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
      );
}
