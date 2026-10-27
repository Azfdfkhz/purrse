import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum BannerKind { error, info }

/// Pesan status (galat / info) dengan ikon + teks: tidak mengandalkan warna saja.
class StatusBanner extends StatelessWidget {
  final String message;
  final BannerKind kind;
  const StatusBanner(this.message, {super.key, this.kind = BannerKind.error});

  @override
  Widget build(BuildContext context) {
    final isError = kind == BannerKind.error;
    final accent = isError ? AppColors.danger : AppColors.success;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: AppColors.isDark ? 0.22 : 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.6)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
                color: AppColors.isDark ? AppColors.textDark : accent, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: AppColors.textDark, fontSize: 14, height: 1.35, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kerangka layar auth: tombol kembali, judul, isi, dan footer. Dapat digulir
/// (aman untuk layar kecil, font besar, dan keyboard terbuka) dan memusat dengan
/// lebar maksimum di layar lebar.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget footer;
  final bool showBack;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    required this.footer,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 480, minHeight: (c.maxHeight - 32).clamp(0.0, double.infinity)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showBack)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: 'Kembali',
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark),
                        ),
                      )
                    else
                      SizedBox(height: 48),
                    SizedBox(height: 12),
                    Semantics(
                      header: true,
                      child: Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 30)),
                    ),
                    SizedBox(height: 6),
                    Text(subtitle, style: TextStyle(color: AppColors.textGrey, fontSize: 15, height: 1.35)),
                    SizedBox(height: 28),
                    ...children,
                    SizedBox(height: 24),
                    footer,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Teks biasa + tautan" di bawah form, dengan area ketuk yang cukup besar.
class AuthFooterLink extends StatelessWidget {
  final String prompt;
  final String action;
  final VoidCallback onTap;
  const AuthFooterLink({super.key, required this.prompt, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('$prompt ', style: TextStyle(color: AppColors.textDark, fontSize: 15)),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 6)),
            child: Text(
              action,
              style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
