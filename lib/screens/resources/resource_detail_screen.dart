import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/resource_model.dart';
import '../../providers/resource_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/shared_widgets.dart';

class ResourceDetailScreen extends ConsumerStatefulWidget {
  final Resource resource;
  const ResourceDetailScreen({super.key, required this.resource});
  @override ConsumerState<ResourceDetailScreen> createState() => _ResourceDetailScreenState();
}

class _ResourceDetailScreenState extends ConsumerState<ResourceDetailScreen> {
  double _userRating = 0;
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      await launchUrl(Uri.parse(widget.resource.fileUrl), mode: LaunchMode.externalApplication);
      await ref.read(resourceServiceProvider).incrementDownloads(widget.resource.id);
    } finally { setState(() => _downloading = false); }
  }

  Future<void> _rate(double r) async {
    setState(() => _userRating = r);
    await ref.read(resourceServiceProvider).rateResource(widget.resource.id, r);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Thanks for rating ${r.toInt()}/5!')));
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Delete Resource'), content: const Text('Are you sure you want to delete this resource?'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: AppTheme.danger)))],
    ));
    if (confirm == true) {
      await ref.read(resourceServiceProvider).deleteResource(widget.resource.id, widget.resource.storagePath);
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.resource;
    final c = Color(int.parse('FF${r.iconColor}', radix: 16));
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: AppTheme.primary, title: Text('Resource Details', style: GoogleFonts.poppins(color: Colors.white))),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header card
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
          gradient: LinearGradient(colors: [c, c.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: Icon(_typeIcon(r.type), color: Colors.white, size: 28)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15), maxLines: 2),
              const SizedBox(height: 4),
              Text('${r.subject} • ${r.department}', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
            ])),
          ])),
        const SizedBox(height: 20),
        // Stats row
        Row(children: [
          _statChip(Icons.download_rounded, '${r.downloads} downloads'),
          const SizedBox(width: 10),
          _statChip(Icons.folder_rounded, r.size),
          const SizedBox(width: 10),
          _statChip(Icons.star_rounded, r.rating.toStringAsFixed(1)),
        ]),
        const SizedBox(height: 20),
        _row('Uploaded by', r.uploadedBy),
        const SizedBox(height: 8),
        _row('Date', DateFormat('MMM d, yyyy').format(r.uploadedAt)),
        _row('Semester', r.semester),
        const SizedBox(height: 24),
        // Rating
        Text('Rate this resource', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.ink900)),
        const SizedBox(height: 8),
        Row(children: List.generate(5, (i) => GestureDetector(
          onTap: () => _rate(i + 1.0),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Icon(
            i < _userRating ? Icons.star_rounded : Icons.star_outline_rounded,
            color: AppTheme.warning, size: 32,
          )),
        ))),
        const SizedBox(height: 28),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _downloading ? null : _download,
          icon: _downloading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.download_rounded, size: 18),
          label: Text(_downloading ? 'Opening...' : 'Download / View',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        )),
        if (user?.uid == r.uploadedById || user?.role == 'faculty') ...[
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: _delete,
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.danger)),
            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 18),
            label: Text('Delete Resource', style: GoogleFonts.inter(color: AppTheme.danger, fontWeight: FontWeight.w600)),
          )),
        ],
      ])),
    );
  }

  Widget _row(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
    Text('$label: ', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.ink600)),
    Text(value, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.ink900)),
  ]));

  Widget _statChip(IconData icon, String label) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: AppTheme.ink600), const SizedBox(width: 4),
      Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.ink600)),
    ]));

  IconData _typeIcon(String type) => switch(type.toUpperCase()) {
    'PDF' => Icons.picture_as_pdf_rounded, 'DOCX' => Icons.description_rounded,
    'PPT' || 'PPTX' => Icons.slideshow_rounded, _ => Icons.image_rounded
  };
}
