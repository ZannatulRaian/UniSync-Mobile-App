import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../providers/resource_provider.dart';
import '../../models/resource_model.dart';
import '../../widgets/shared_widgets.dart';
import 'resource_detail_screen.dart';
import 'resource_upload_screen.dart';

class ResourcesScreen extends ConsumerStatefulWidget {
  const ResourcesScreen({super.key});
  @override ConsumerState<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends ConsumerState<ResourcesScreen> {
  String _dept   = 'All';
  String _type   = 'All';
  String _search = '';

  static const _depts = ['All','Computer Science','Mathematics','Physics','EEE','Business','English'];
  static const _types = ['All','PDF','DOCX','PPT','Image'];

  @override
  Widget build(BuildContext context) {
    // FIX: use ResourceFilter object, not a raw Map
    final filter       = ResourceFilter(
      dept: _dept == 'All' ? null : _dept,
      type: _type == 'All' ? null : _type,
    );
    final resourcesAsync = ref.watch(resourcesStreamProvider(filter));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: Text('Resources',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_rounded, color: Colors.white),
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ResourceUploadScreen())),
          ),
        ],
      ),
      body: CustomScrollView(slivers: [
        // Search bar
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: AppSearchBar(
            hint: 'Search resources...',
            onChanged: (v) => setState(() => _search = v)),
        )),
        // Department filter chips
        SliverToBoxAdapter(child: SizedBox(height: 40, child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _depts.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: CategoryChip(
              label: _depts[i],
              isSelected: _dept == _depts[i],
              onTap: () => setState(() => _dept = _depts[i]),
            )),
        ))),
        // Type filter chips
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(children: _types.map((tp) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(tp, style: GoogleFonts.inter(fontSize: 12)),
              selected: _type == tp,
              selectedColor: AppTheme.primaryLight,
              backgroundColor: AppTheme.surface,
              side: BorderSide(color: _type == tp ? AppTheme.primary : AppTheme.border),
              onSelected: (_) => setState(() => _type = tp),
            ),
          )).toList()),
        )),
        // Results
        resourcesAsync.when(
          loading: () => SliverList(delegate: SliverChildBuilderDelegate(
            (_, __) => const ShimmerCard(), childCount: 4)),
          error: (e, _) => SliverToBoxAdapter(child: AppError(
            message: 'Failed to load resources',
            onRetry: () => ref.invalidate(resourcesStreamProvider(filter)),
          )),
          data: (resources) {
            final filtered = _search.isEmpty
                ? resources
                : resources.where((r) =>
                    r.title.toLowerCase().contains(_search.toLowerCase()) ||
                    r.subject.toLowerCase().contains(_search.toLowerCase())).toList();
            if (filtered.isEmpty) return const SliverFillRemaining(
              child: EmptyState(
                icon: Icons.menu_book_outlined,
                title: 'No resources found',
                subtitle: 'Try different filters or upload one!'));
            return SliverList(delegate: SliverChildBuilderDelegate(
              (_, i) => _ResourceTile(filtered[i]),
              childCount: filtered.length));
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ]),
    );
  }
}

class _ResourceTile extends StatelessWidget {
  final Resource r;
  const _ResourceTile(this.r);

  @override
  Widget build(BuildContext context) {
    final c = Color(int.parse('FF${r.iconColor}', radix: 16));
    return GestureDetector(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => ResourceDetailScreen(resource: r))),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardOverlay,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: c.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(_typeIcon(r.type), color: c, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.ink900),
              maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('${r.subject} • ${r.department}',
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.ink400)),
            const SizedBox(height: 4),
            Row(children: [
              TypeBadge(type: r.type),
              const SizedBox(width: 8),
              StarRating(rating: r.rating),
              const SizedBox(width: 4),
              Text(r.rating.toStringAsFixed(1),
                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.ink600)),
              const Spacer(),
              const Icon(Icons.download_rounded, size: 12, color: AppTheme.ink400),
              const SizedBox(width: 2),
              Text('${r.downloads}',
                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.ink400)),
              const SizedBox(width: 8),
              Text(r.size,
                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.ink400)),
            ]),
          ])),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.ink400),
        ]),
      ),
    );
  }

  IconData _typeIcon(String type) => switch (type.toUpperCase()) {
    'PDF'           => Icons.picture_as_pdf_rounded,
    'DOCX' || 'DOC' => Icons.description_rounded,
    'PPT' || 'PPTX' => Icons.slideshow_rounded,
    _               => Icons.image_rounded,
  };
}
