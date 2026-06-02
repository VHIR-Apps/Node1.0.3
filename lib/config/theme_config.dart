import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_config.dart';

class ThemeConfig {
  const ThemeConfig._();

  // Premium surfaces tuned for your existing UI colors
  static const Color _lightScaffold = Color(0xFFF7F8FC);
  static const Color _lightSurface = Colors.white;

  static const Color _darkScaffold = Color(0xFF0B1020);
  static const Color _darkSurface = Color(0xFF151C2F);
  static const Color _darkSurface2 = Color(0xFF1A2235);

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
    );

    final colorScheme = const ColorScheme.light(
      primary: AppConfig.primaryColor,
      secondary: AppConfig.accentColor,
      surface: _lightSurface,
      onSurface: Color(0xFF0F172A),
      error: AppConfig.errorColor,
    );

    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).apply(
      bodyColor: const Color(0xFF0F172A),
      displayColor: const Color(0xFF0F172A),
    );

    return base.copyWith(
      colorScheme: colorScheme,
      primaryColor: AppConfig.primaryColor,
      scaffoldBackgroundColor: _lightScaffold,
      textTheme: textTheme,

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF0F172A),
        ),
      ),

      cardColor: _lightSurface,
      cardTheme: CardThemeData(
        elevation: 0,
        color: _lightSurface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: _lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w900,
          color: const Color(0xFF0F172A),
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          height: 1.45,
          color: const Color(0xFF334155),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _lightSurface,
        modalBackgroundColor: _lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: Colors.black.withOpacity(0.08),
        thickness: 1,
        space: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: const Color(0xFF111827),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.black.withOpacity(0.03),
        isDense: true,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF64748B),
          fontWeight: FontWeight.w500,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF334155),
          fontWeight: FontWeight.w600,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppConfig.primaryColor,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppConfig.errorColor,
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppConfig.errorColor,
            width: 2,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConfig.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConfig.buttonBorderRadius),
          ),
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppConfig.primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConfig.buttonBorderRadius),
          ),
          textStyle:
          textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppConfig.primaryColor,
          side: BorderSide(color: AppConfig.primaryColor.withOpacity(0.35)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConfig.buttonBorderRadius),
          ),
          textStyle:
          textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return Colors.white;
          return const Color(0xFFCBD5E1);
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppConfig.primaryColor.withOpacity(0.55);
          }
          return const Color(0xFFE2E8F0);
        }),
      ),

      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: Colors.black.withOpacity(0.22)),
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppConfig.primaryColor;
          }
          return Colors.transparent;
        }),
        checkColor: MaterialStateProperty.all(Colors.white),
      ),

      // FIX: Detailed TimePickerTheme for Light Mode
      timePickerTheme: TimePickerThemeData(
        backgroundColor: _lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        dialBackgroundColor: Colors.black.withOpacity(0.04),
        dialHandColor: AppConfig.primaryColor,
        dialTextColor: MaterialStateColor.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return Colors.white;
          return const Color(0xFF0F172A);
        }),
        hourMinuteColor: MaterialStateColor.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppConfig.primaryColor.withOpacity(0.15);
          }
          return Colors.black.withOpacity(0.05);
        }),
        hourMinuteTextColor: MaterialStateColor.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppConfig.primaryColor;
          }
          return const Color(0xFF0F172A);
        }),
        dayPeriodColor: MaterialStateColor.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppConfig.primaryColor.withOpacity(0.15);
          }
          return Colors.black.withOpacity(0.05);
        }),
        dayPeriodTextColor: MaterialStateColor.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppConfig.primaryColor;
          }
          return const Color(0xFF0F172A);
        }),
        entryModeIconColor: const Color(0xFF0F172A),
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
    );

    final colorScheme = const ColorScheme.dark(
      primary: AppConfig.primaryColor,
      secondary: AppConfig.accentColor,
      surface: _darkSurface,
      onSurface: Color(0xFFE5E7EB),
      error: AppConfig.errorColor,
    );

    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).apply(
      bodyColor: const Color(0xFFE5E7EB),
      displayColor: const Color(0xFFE5E7EB),
    );

    return base.copyWith(
      colorScheme: colorScheme,
      primaryColor: AppConfig.primaryColor,
      scaffoldBackgroundColor: _darkScaffold,
      textTheme: textTheme,

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFFE5E7EB),
        iconTheme: const IconThemeData(color: Color(0xFFE5E7EB)),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: const Color(0xFFE5E7EB),
        ),
      ),

      cardColor: _darkSurface,
      cardTheme: CardThemeData(
        elevation: 0,
        color: _darkSurface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: _darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          height: 1.45,
          color: Colors.white.withOpacity(0.78),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _darkSurface,
        modalBackgroundColor: _darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: Colors.white.withOpacity(0.08),
        thickness: 1,
        space: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurface2.withOpacity(0.85),
        isDense: true,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white.withOpacity(0.45),
          fontWeight: FontWeight.w500,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white.withOpacity(0.72),
          fontWeight: FontWeight.w600,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppConfig.primaryColor,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppConfig.errorColor,
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppConfig.errorColor,
            width: 2,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConfig.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConfig.buttonBorderRadius),
          ),
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppConfig.primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConfig.buttonBorderRadius),
          ),
          textStyle:
          textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor:
          Color.lerp(AppConfig.primaryColor, Colors.white, 0.10),
          side: BorderSide(color: Colors.white.withOpacity(0.10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConfig.buttonBorderRadius),
          ),
          textStyle:
          textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return Colors.white;
          return Colors.white.withOpacity(0.55);
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppConfig.primaryColor.withOpacity(0.55);
          }
          return Colors.white.withOpacity(0.16);
        }),
      ),

      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: Colors.white.withOpacity(0.22)),
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppConfig.primaryColor;
          }
          return Colors.transparent;
        }),
        checkColor: MaterialStateProperty.all(Colors.white),
      ),

      // FIX: Detailed TimePickerTheme for Dark Mode to stop the white face bug
      timePickerTheme: TimePickerThemeData(
        backgroundColor: _darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        dialBackgroundColor: _darkSurface2, // This fixes the bright white clock face!
        dialHandColor: AppConfig.primaryColor,
        dialTextColor: MaterialStateColor.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return Colors.white;
          return Colors.white.withOpacity(0.85);
        }),
        hourMinuteColor: MaterialStateColor.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppConfig.primaryColor.withOpacity(0.3);
          }
          return _darkSurface2;
        }),
        hourMinuteTextColor: MaterialStateColor.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppConfig.primaryColor;
          }
          return Colors.white;
        }),
        dayPeriodColor: MaterialStateColor.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppConfig.primaryColor.withOpacity(0.3);
          }
          return _darkSurface2;
        }),
        dayPeriodTextColor: MaterialStateColor.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppConfig.primaryColor;
          }
          return Colors.white.withOpacity(0.85);
        }),
        entryModeIconColor: Colors.white.withOpacity(0.85),
      ),
    );
  }
}