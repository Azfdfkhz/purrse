import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'purrse_motion.dart';

class AppTheme {
  AppTheme._();

  /// Membangun tema sesuai [AppColors.isDark] yang sudah disinkronkan oleh
  /// ThemeController sebelum dipanggil.
  static ThemeData build({Color? accent}) {
    final dark = AppColors.isDark;
    final acc = accent ?? AppColors.soft;
    final base = dark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
    final onAccent = AppColors.onColor(acc);
    final text = AppColors.textDark;

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      pageTransitionsTheme: PurrsePageTransitions.theme,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: dark ? AppColors.inkInverse : AppColors.ink,
        selectionHandleColor: dark ? AppColors.inkInverse : AppColors.ink,
        selectionColor: AppColors.ink.withOpacity(0.25),
      ),
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.ink,
        onPrimary: AppColors.onInk,
        primaryContainer: acc,
        onPrimaryContainer: onAccent,
        secondary: acc,
        onSecondary: onAccent,
        surface: AppColors.surface,
        onSurface: text,
        error: AppColors.danger,
      ),
      dividerColor: AppColors.border,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: text,
        displayColor: text,
      ).copyWith(
        displayLarge: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: text, letterSpacing: -0.4),
        headlineMedium: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: text, letterSpacing: -0.4),
        titleLarge: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: text, letterSpacing: -0.4),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: GoogleFonts.inter(
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
        titleTextStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 20, color: text),
        contentTextStyle: GoogleFonts.inter(fontSize: 14, color: text),
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
          side: BorderSide(color: AppColors.border, width: 1),
          minimumSize: Size(48, 48),
          shape: StadiumBorder(),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 20, color: text),
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
        backgroundColor: acc,
        foregroundColor: onAccent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: dark ? acc : AppColors.ink),
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
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.border, width: 1),
        ),
        hintStyle: TextStyle(color: AppColors.textGrey),
        labelStyle: TextStyle(color: AppColors.textGrey),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: dark ? acc : AppColors.ink, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),
    );
  }

  /// Kompatibilitas dengan pemanggilan lama.
  static ThemeData light({Color? accent}) => build(accent: accent);
}
