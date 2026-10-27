import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  /// Membangun tema sesuai [AppColors.isDark] yang sudah disinkronkan oleh
  /// ThemeController sebelum dipanggil.
  static ThemeData build({Color accent = AppColors.softPurple}) {
    final dark = AppColors.isDark;
    final base = dark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
    final onAccent = AppColors.onColor(accent);
    final text = AppColors.textDark;

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        onPrimary: onAccent,
        secondary: accent,
        onSecondary: onAccent,
        surface: AppColors.surface,
        onSurface: text,
        error: AppColors.danger,
      ),
      dividerColor: AppColors.border,
      textTheme: GoogleFonts.nunitoTextTheme(base.textTheme).apply(
        bodyColor: text,
        displayColor: text,
      ).copyWith(
        displayLarge: GoogleFonts.baloo2(fontWeight: FontWeight.w700, color: text),
        headlineMedium: GoogleFonts.baloo2(fontWeight: FontWeight.w700, color: text),
        titleLarge: GoogleFonts.baloo2(fontWeight: FontWeight.w700, color: text),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: GoogleFonts.nunito(
          color: AppColors.onInk,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.baloo2(fontWeight: FontWeight.w700, fontSize: 20, color: text),
        contentTextStyle: GoogleFonts.nunito(fontSize: 14, color: text),
      ),
      timePickerTheme: TimePickerThemeData(backgroundColor: AppColors.surface),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(textColor: text, iconColor: text),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: text,
          minimumSize: Size(48, 48),
          textStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.onInk,
          minimumSize: Size(48, 52),
          shape: StadiumBorder(),
          textStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: BorderSide(color: AppColors.ink, width: 1.5),
          minimumSize: Size(48, 48),
          shape: StadiumBorder(),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 18, color: text),
        iconTheme: IconThemeData(color: text),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.onInk,
          elevation: 0,
          minimumSize: Size(48, 52),
          shape: StadiumBorder(),
          textStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onAccent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: dark ? accent : AppColors.ink),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.selected) ? AppColors.onInk : AppColors.textGrey,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.selected) ? AppColors.ink : AppColors.surfaceVariant,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.selected) ? AppColors.ink : AppColors.border,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: AppColors.textGrey),
        labelStyle: TextStyle(color: AppColors.textGrey),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: dark ? accent : AppColors.ink, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),
    );
  }

  /// Kompatibilitas dengan pemanggilan lama.
  static ThemeData light({Color accent = AppColors.softPurple}) => build(accent: accent);
}
