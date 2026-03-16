import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../theme/app_theme.dart';
import '../auth/signup_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});
  @override State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _InfoPage {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  const _InfoPage(this.title, this.subtitle, this.icon, this.color);
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc     = PageController();
  int    _page  = 0;
  String? _selectedRole;
  final  _idCtrl = TextEditingController();
  String? _idError;

  static const _infoPages = [
    _InfoPage('Events & RSVP',
      'Browse, create and RSVP to campus events all in one place.',
      Icons.event_rounded, AppTheme.primary),
    _InfoPage('Study Resources',
      'Upload and download notes, slides, and PDFs organized by subject.',
      Icons.menu_book_rounded, AppTheme.accent),
    _InfoPage('Stay Connected',
      'Group chats, announcements, and real-time updates — all in one app.',
      Icons.chat_bubble_rounded, Color(0xFF9B59B6)),
  ];

  int  get _totalPages => _infoPages.length + 1;
  bool get _isRoleSlide => _page == _infoPages.length;
  Color get _currentColor => _isRoleSlide ? AppTheme.primary : _infoPages[_page].color;

  @override
  void dispose() { _pc.dispose(); _idCtrl.dispose(); super.dispose(); }

  void _proceedFromRoleSlide() {
    final id = _idCtrl.text.trim();
    if (_selectedRole == null) {
      setState(() => _idError = 'Please select Student or Faculty first');
      return;
    }
    if (_selectedRole == 'student' && !RegExp(r'^3[0-9]{7}$').hasMatch(id)) {
      setState(() => _idError = 'Student ID must start with 3 and be exactly 8 digits (e.g. 31234567)');
      return;
    }
    if (_selectedRole == 'faculty' && !RegExp(r'^1[0-9]{7}$').hasMatch(id)) {
      setState(() => _idError = 'Faculty ID must start with 1 and be exactly 8 digits (e.g. 11234567)');
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => SignupScreen(preselectedRole: _selectedRole!, prefilledId: id),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(child: Column(children: [
        if (!_isRoleSlide)
          Align(alignment: Alignment.topRight,
            child: Padding(padding: const EdgeInsets.only(right: 8, top: 4),
              child: TextButton(
                onPressed: () => _pc.animateToPage(_infoPages.length,
                  duration: const Duration(milliseconds: 400), curve: Curves.ease),
                child: Text('Skip', style: GoogleFonts.inter(color: AppTheme.ink400, fontWeight: FontWeight.w500)),
              )))
        else
          const SizedBox(height: 44),

        Expanded(child: PageView.builder(
          controller: _pc,
          itemCount: _totalPages,
          onPageChanged: (i) => setState(() { _page = i; _idError = null; }),
          itemBuilder: (_, i) => i < _infoPages.length
              ? _buildInfoPage(_infoPages[i])
              : _buildRoleSlide(),
        )),

        Padding(padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(children: [
            SmoothPageIndicator(controller: _pc, count: _totalPages,
              effect: ExpandingDotsEffect(dotHeight: 8, dotWidth: 8,
                activeDotColor: _currentColor, dotColor: AppTheme.border)),
            const SizedBox(height: 28),
            Row(children: [
              if (_page > 0) ...[
                Expanded(child: OutlinedButton(
                  onPressed: () => _pc.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.ease),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: _currentColor), padding: const EdgeInsets.symmetric(vertical: 15)),
                  child: Text('Back', style: GoogleFonts.inter(color: _currentColor, fontWeight: FontWeight.w600)))),
                const SizedBox(width: 12),
              ],
              Expanded(child: ElevatedButton(
                onPressed: _isRoleSlide
                    ? _proceedFromRoleSlide
                    : () => _pc.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease),
                style: ElevatedButton.styleFrom(backgroundColor: _currentColor, padding: const EdgeInsets.symmetric(vertical: 15)),
                child: Text(_isRoleSlide ? 'Continue to Sign Up' : 'Next',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)))),
            ]),
          ])),
      ])),
    );
  }

  Widget _buildInfoPage(_InfoPage p) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 76, height: 76,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0,2))],
        ),
        padding: const EdgeInsets.all(8),
        child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
      ),
      const SizedBox(height: 32),
      Container(width: 160, height: 160,
        decoration: BoxDecoration(color: p.color.withOpacity(0.08), borderRadius: BorderRadius.circular(32), border: Border.all(color: p.color.withOpacity(0.15))),
        child: Icon(p.icon, size: 72, color: p.color)),
      const SizedBox(height: 32),
      Text(p.title, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.ink900)),
      const SizedBox(height: 12),
      Text(p.subtitle, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 15, color: AppTheme.ink600, height: 1.5)),
    ]));

  Widget _buildRoleSlide() => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 32),
    child: Column(children: [
      const SizedBox(height: 8),
      Container(
        width: 76, height: 76,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0,2))],
        ),
        padding: const EdgeInsets.all(8),
        child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
      ),
      const SizedBox(height: 24),
      Text('Who are you?', textAlign: TextAlign.center,
        style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.ink900)),
      const SizedBox(height: 8),
      Text('Select your role — it is determined by your ID number.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(fontSize: 14, color: AppTheme.ink600, height: 1.5)),
      const SizedBox(height: 28),
      Row(children: [
        Expanded(child: _RoleCard(icon: Icons.school_outlined, label: 'Student', hint: '',
          selected: _selectedRole == 'student', color: AppTheme.primary,
          onTap: () => setState(() { _selectedRole = 'student'; _idError = null; }))),
        const SizedBox(width: 14),
        Expanded(child: _RoleCard(icon: Icons.person_4_outlined, label: 'Faculty', hint: '',
          selected: _selectedRole == 'faculty', color: AppTheme.accent,
          onTap: () => setState(() { _selectedRole = 'faculty'; _idError = null; }))),
      ]),
      const SizedBox(height: 24),
      TextField(
        controller: _idCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
        onChanged: (_) => setState(() => _idError = null),
        decoration: InputDecoration(
          labelText: _selectedRole == 'faculty'
              ? 'Faculty ID (8 digits, starts with 1)'
              : 'Student ID (8 digits, starts with 3)',
          hintText: _selectedRole == 'faculty' ? 'e.g. 11234567' : 'e.g. 31234567',
          prefixIcon: const Icon(Icons.badge_outlined, size: 18),
          errorText: _idError, errorMaxLines: 2,
        ),
      ),
      const SizedBox(height: 8),
    ]));
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String label, hint;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _RoleCard({required this.icon, required this.label, required this.hint,
    required this.selected, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: selected ? color.withOpacity(0.08) : AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? color : AppTheme.border, width: selected ? 2 : 1)),
      child: Column(children: [
        Icon(icon, size: 36, color: selected ? color : AppTheme.ink400),
        const SizedBox(height: 10),
        Text(label, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700,
          color: selected ? color : AppTheme.ink900)),
        const SizedBox(height: 4),
        if (hint.isNotEmpty) Text(hint, style: GoogleFonts.inter(fontSize: 11, color: selected ? color : AppTheme.ink400)),
      ])));
}
