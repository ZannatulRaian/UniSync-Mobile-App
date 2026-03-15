import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

// ── Loading shimmer
class ShimmerCard extends StatelessWidget {
  final double height;
  const ShimmerCard({super.key, this.height = 80});
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100,
    child: Container(height: height, margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
  );
}

// ── Empty state
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, required this.subtitle, this.action});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 64, color: AppTheme.ink400),
      const SizedBox(height: 16),
      Text(title, style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.ink900)),
      const SizedBox(height: 6),
      Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.ink400)),
      if (action != null) ...[const SizedBox(height: 20), action!],
    ]),
  ));
}

// ── Category chip
class CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const CategoryChip({super.key, required this.label, required this.isSelected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primary : AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.border),
      ),
      child: Text(label, style: GoogleFonts.inter(
        fontSize: 13, fontWeight: FontWeight.w500,
        color: isSelected ? Colors.white : AppTheme.ink600,
      )),
    ),
  );
}

// ── Star rating
class StarRating extends StatelessWidget {
  final double rating;
  final double size;
  const StarRating({super.key, required this.rating, this.size = 14});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (i) => Icon(
      i < rating.floor() ? Icons.star_rounded
          : i < rating ? Icons.star_half_rounded : Icons.star_outline_rounded,
      size: size, color: AppTheme.warning,
    )),
  );
}

// ── Search bar
class AppSearchBar extends StatelessWidget {
  final String hint;
  final ValueChanged<String>? onChanged;
  const AppSearchBar({super.key, this.hint = 'Search...', this.onChanged});
  @override
  Widget build(BuildContext context) => TextField(
    onChanged: onChanged,
    style: GoogleFonts.inter(fontSize: 14, color: AppTheme.ink900),
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.ink400),
      filled: true, fillColor: AppTheme.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    ),
  );
}

// ── Section header
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader({super.key, required this.title, this.action, this.onAction});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
    child: Row(children: [
      Expanded(child: Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.ink900))),
      if (action != null) GestureDetector(onTap: onAction, child: Text(action!, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w500))),
    ]),
  );
}

// ── Type badge
class TypeBadge extends StatelessWidget {
  final String type;
  const TypeBadge({super.key, required this.type});
  static Color _color(String t) => switch(t.toUpperCase()) {
    'PDF' => AppTheme.danger, 'DOCX' => AppTheme.primary, 'PPT' || 'PPTX' => AppTheme.warning,
    'IMG' || 'IMAGE' || 'JPG' || 'PNG' => AppTheme.accent, _ => AppTheme.ink400
  };
  @override
  Widget build(BuildContext context) {
    final c = _color(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(type.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
    );
  }
}

// ── Error widget
class AppError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const AppError({super.key, required this.message, this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.danger),
    const SizedBox(height: 12),
    Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppTheme.ink600)),
    if (onRetry != null) ...[const SizedBox(height: 12),
      ElevatedButton(onPressed: onRetry, child: const Text('Retry'))],
  ]));
}
