import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import 'home_tab.dart';
import '../events/events_list_screen.dart';
import '../resources/resources_screen.dart';
import '../chat/chat_list_screen.dart';
import '../profile/profile_screen.dart';

class MainDashboard extends ConsumerStatefulWidget {
  const MainDashboard({super.key});
  @override ConsumerState<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends ConsumerState<MainDashboard> {
  int _idx = 0;

  static const _tabs = [
    _NavItem(Icons.home_rounded, Icons.home_outlined, 'Home'),
    _NavItem(Icons.event_rounded, Icons.event_outlined, 'Events'),
    _NavItem(Icons.menu_book_rounded, Icons.menu_book_outlined, 'Resources'),
    _NavItem(Icons.chat_bubble_rounded, Icons.chat_bubble_outline_rounded, 'Chat'),
    _NavItem(Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(index: _idx, children: const [
          HomeTab(), EventsListScreen(), ResourcesScreen(), ChatListScreen(), ProfileScreen(),
        ]),
        bottomNavigationBar: _buildNav(),
      ),
    );
  }

  Widget _buildNav() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.55),
            border: const Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
          ),
          child: SafeArea(top: false, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_tabs.length, (i) => _NavBtn(
                item: _tabs[i], index: i, current: _idx, onTap: (i) => setState(() => _idx = i),
              ))),
          )),
        ),
      ),
    );
  }
}

class _NavItem { final IconData active, inactive; final String label; const _NavItem(this.active, this.inactive, this.label); }

class _NavBtn extends StatelessWidget {
  final _NavItem item; final int index, current; final ValueChanged<int> onTap;
  const _NavBtn({super.key, required this.item, required this.index, required this.current, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final on = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: on ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: on ? [BoxShadow(color: AppTheme.primary.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))] : [],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(on ? item.active : item.inactive,
            color: on ? Colors.white : Colors.black54, size: 24),
          const SizedBox(height: 3),
          Text(item.label, style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: on ? FontWeight.w700 : FontWeight.w400,
            color: on ? Colors.white : Colors.black54,
          )),
        ]),
      ),
    );
  }
}
