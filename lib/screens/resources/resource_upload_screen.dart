import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../../theme/app_theme.dart';
import '../../providers/resource_provider.dart';
import '../../providers/auth_provider.dart';

class ResourceUploadScreen extends ConsumerStatefulWidget {
  const ResourceUploadScreen({super.key});
  @override ConsumerState<ResourceUploadScreen> createState() => _ResourceUploadScreenState();
}

class _ResourceUploadScreenState extends ConsumerState<ResourceUploadScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _titleCtrl   = TextEditingController();
  final _subjectCtrl = TextEditingController();
  File?   _file;
  String? _fileName;
  String _dept     = 'Computer Science';
  String _semester = '6th';
  String _type     = 'PDF';
  bool   _loading  = false;

  static const _depts = ['Computer Science','Mathematics','Physics','EEE','Business','English','Other'];
  static const _sems  = ['1st','2nd','3rd','4th','5th','6th','7th','8th'];

  @override void dispose() { _titleCtrl.dispose(); _subjectCtrl.dispose(); super.dispose(); }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf','doc','docx','ppt','pptx','jpg','jpeg','png'],
    );
    if (result != null && result.files.single.path != null) {
      final ext = result.files.single.extension?.toUpperCase() ?? 'PDF';
      setState(() {
        _file     = File(result.files.single.path!);
        _fileName = result.files.single.name;
        _type     = ext;
      });
    }
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_file == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a file first')));
      return;
    }
    setState(() => _loading = true);
    final user = ref.read(currentUserProvider);
    // SECURITY: ensure user is authenticated before uploading
    if (user == null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be signed in to upload'), backgroundColor: AppTheme.danger));
      return;
    }
    try {
      await ref.read(resourceServiceProvider).uploadResource(
        file:         _file!,
        title:        _titleCtrl.text.trim(),
        subject:      _subjectCtrl.text.trim(),
        department:   _dept,
        semester:     _semester,
        type:         _type,
        uploadedBy:   user.name,
        uploadedById: user.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Uploaded successfully!'), backgroundColor: AppTheme.accent));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ','')), backgroundColor: AppTheme.danger));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: AppTheme.primary,
          title: Text('Upload Resource', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // File picker area
          GestureDetector(onTap: _loading ? null : _pickFile,
              child: Container(width: double.infinity, padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border.all(color: _file != null ? AppTheme.accent : AppTheme.border, width: _file != null ? 2 : 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(children: [
                  Icon(_file != null ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                      size: 44, color: _file != null ? AppTheme.accent : AppTheme.ink400),
                  const SizedBox(height: 8),
                  Text(_fileName ?? 'Tap to select a file',
                      style: GoogleFonts.inter(color: _file != null ? AppTheme.accent : AppTheme.ink600,
                          fontWeight: _file != null ? FontWeight.w600 : FontWeight.w400),
                      textAlign: TextAlign.center),
                  if (_file == null) ...[
                    const SizedBox(height: 4),
                    Text('PDF, DOCX, PPT, JPG, PNG  •  Max 10 MB',
                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.ink400)),
                  ],
                ]),
              )),
          const SizedBox(height: 20),
          _lbl('Title'), const SizedBox(height: 6),
          TextFormField(controller: _titleCtrl, decoration: const InputDecoration(hintText: 'e.g. Data Structures Notes'),
              validator: (v) => v!.trim().isNotEmpty ? null : 'Required'),
          const SizedBox(height: 14),
          _lbl('Subject'), const SizedBox(height: 6),
          TextFormField(controller: _subjectCtrl, decoration: const InputDecoration(hintText: 'e.g. Data Structures'),
              validator: (v) => v!.trim().isNotEmpty ? null : 'Required'),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _lbl('Department'), const SizedBox(height: 6),
              DropdownButtonFormField<String>(value: _dept, isExpanded: true,
                  dropdownColor: Colors.white,
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                  items: _depts.map((d) => DropdownMenuItem(value: d, child: Text(d, style: GoogleFonts.inter(fontSize: 12)))).toList(),
                  onChanged: (v) => setState(() => _dept = v!)),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _lbl('Semester'), const SizedBox(height: 6),
              DropdownButtonFormField<String>(value: _semester, isExpanded: true,
                  dropdownColor: Colors.white,
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                  items: _sems.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _semester = v!)),
            ])),
          ]),
          if (_loading) ...[
            const SizedBox(height: 20),
            const LinearProgressIndicator(color: AppTheme.accent),
            const SizedBox(height: 8),
            Center(child: Text('Uploading...', style: GoogleFonts.inter(color: AppTheme.ink600, fontSize: 13))),
          ],
          const SizedBox(height: 28),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _loading ? null : _upload,
            icon: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.upload_rounded, size: 18),
            label: Text(_loading ? 'Uploading...' : 'Upload Resource'),
          )),
        ])),
      ),
    );
  }

  Widget _lbl(String t) => Text(t, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.ink900));
}