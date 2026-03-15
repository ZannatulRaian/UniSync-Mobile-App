import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary      = Color(0xFF1A56DB);
  static const Color primaryDark  = Color(0xFF1039A0);
  static const Color primaryLight = Color(0xFFEBF0FF);
  static const Color accent       = Color(0xFF0E9F6E);
  static const Color accentLight  = Color(0xFFDEF7EC);
  static const Color warning      = Color(0xFFE3A008);
  static const Color danger       = Color(0xFFE02424);
  static const Color dangerLight  = Color(0xFFFDE8E8);
  static const Color bg           = Color(0xE8F4F6FA);
  static const Color surface      = Color(0xEEFFFFFF);
  static const Color border       = Color(0xFFDDE1EC);
  static const Color ink900       = Color(0xFF111928);
  static const Color ink600       = Color(0xFF4B5563);
  static const Color ink400       = Color(0xFF9CA3AF);
  static const Color cardOverlay  = Color(0xE8FFFFFF);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  // Alias used by main.dart
  static ThemeData get theme => lightTheme;

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: primary, primary: primary, secondary: accent),
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.transparent,
    textTheme: GoogleFonts.interTextTheme().copyWith(
      headlineSmall: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: ink900, fontSize: 16),
      headlineMedium: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: ink900, fontSize: 18),
      bodyMedium: GoogleFonts.inter(color: ink600, fontSize: 14),
      bodySmall: GoogleFonts.inter(color: ink400, fontSize: 12),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: primary, elevation: 0, centerTitle: false,
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 18),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary, foregroundColor: Colors.white, elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primary, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: danger)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      hintStyle: GoogleFonts.inter(color: ink400, fontSize: 14),
    ),
    cardTheme: CardThemeData(color: cardOverlay, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    dividerTheme: const DividerThemeData(color: border, space: 1, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: ink900, contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), behavior: SnackBarBehavior.floating,
    ),
  );
}

class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Stack(children: [
    // Background image — full cover, full opacity
    Positioned.fill(child: Image.asset(
      'assets/images/background.jpg',
      fit: BoxFit.cover,
    )),
    child,
  ]);
}

class BgScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool extendBodyBehindAppBar;
  const BgScaffold({super.key, this.appBar, this.body, this.bottomNavigationBar,
    this.floatingActionButton, this.extendBodyBehindAppBar = false});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent, extendBodyBehindAppBar: extendBodyBehindAppBar,
    appBar: appBar, body: body,
    bottomNavigationBar: bottomNavigationBar, floatingActionButton: floatingActionButton,
  );
}
