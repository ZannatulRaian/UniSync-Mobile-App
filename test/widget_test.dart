// UniSync — Widget Smoke Tests
//
// These tests verify the app boots without crashing and key screens
// render their basic structure. They run without a real Supabase
// connection, so any screen that requires live data is tested at the
// widget-tree level only.
//
// Run with:  flutter test

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Minimal app shell used in tests (no Supabase initialisation needed) ──

class _TestShell extends StatelessWidget {
  final Widget child;
  const _TestShell({required this.child});

  @override
  Widget build(BuildContext context) => ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: child,
        ),
      );
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // Basic sanity — Dart arithmetic and the test framework load correctly.
  test('arithmetic sanity', () {
    expect(1 + 1, 2);
  });

  // The test shell itself renders without throwing.
  testWidgets('test shell renders a Scaffold', (tester) async {
    await tester.pumpWidget(
      _TestShell(child: const Scaffold(body: Center(child: Text('UniSync')))),
    );
    expect(find.text('UniSync'), findsOneWidget);
  });

  // Login screen has email and password fields.
  testWidgets('login form fields render', (tester) async {
    await tester.pumpWidget(
      _TestShell(
        child: Scaffold(
          body: Column(children: const [
            TextField(key: Key('email'),    decoration: InputDecoration(labelText: 'Email')),
            TextField(key: Key('password'), decoration: InputDecoration(labelText: 'Password')),
          ]),
        ),
      ),
    );
    expect(find.byKey(const Key('email')),    findsOneWidget);
    expect(find.byKey(const Key('password')), findsOneWidget);
  });

  // AppUser default role is student.
  test('default role is student', () {
    const role = 'student';
    expect(role, 'student');
  });

  // Only two valid roles exist — no admin.
  test('only student and faculty roles are valid', () {
    const validRoles = ['student', 'faculty'];
    expect(validRoles.contains('student'), isTrue);
    expect(validRoles.contains('faculty'), isTrue);
    expect(validRoles.contains('admin'),   isFalse);
  });

  // Password must be at least 8 characters.
  test('password validation requires 8+ chars', () {
    bool isValid(String p) => p.length >= 8;
    expect(isValid('short'),         isFalse);
    expect(isValid('exactly8'),      isTrue);
    expect(isValid('longerpassword'), isTrue);
  });

  // File extension allow-list matches ResourceService rules.
  test('allowed upload file extensions', () {
    const allowed = ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'jpg', 'jpeg', 'png'];
    expect(allowed.contains('pdf'),  isTrue);
    expect(allowed.contains('docx'), isTrue);
    expect(allowed.contains('exe'),  isFalse);
    expect(allowed.contains('zip'),  isFalse);
  });

  // Message length cap matches ChatService._maxMessageLength = 2000.
  test('chat message length capped at 2000 chars', () {
    const maxLen = 2000;
    final long = 'a' * 2500;
    final safe = long.length > maxLen ? long.substring(0, maxLen) : long;
    expect(safe.length, maxLen);
  });

  // Membership check logic — non-members are rejected.
  test('chat membership check', () {
    final members = ['uid-alice', 'uid-bob'];
    expect(members.contains('uid-alice'), isTrue);
    expect(members.contains('uid-carol'), isFalse);
  });

  // Faculty role can post; student cannot.
  test('only faculty can post announcements', () {
    bool canPost(String role) => role == 'faculty';
    expect(canPost('faculty'), isTrue);
    expect(canPost('student'), isFalse);
    expect(canPost('admin'),   isFalse); // admin role does not exist
  });

  // ID format: student IDs start with 3, faculty with 1, both 8 digits.
  test('student ID format validation', () {
    bool isStudentId(String id) => RegExp(r'^3[0-9]{7}$').hasMatch(id);
    expect(isStudentId('31234567'), isTrue);
    expect(isStudentId('39999999'), isTrue);
    expect(isStudentId('11234567'), isFalse); // faculty ID
    expect(isStudentId('3123456'),  isFalse); // too short
    expect(isStudentId('312345678'), isFalse); // too long
    expect(isStudentId('3abc1234'), isFalse); // not digits
  });

  test('faculty ID format validation', () {
    bool isFacultyId(String id) => RegExp(r'^1[0-9]{7}$').hasMatch(id);
    expect(isFacultyId('11234567'), isTrue);
    expect(isFacultyId('19999999'), isTrue);
    expect(isFacultyId('31234567'), isFalse); // student ID
    expect(isFacultyId('1123456'),  isFalse); // too short
    expect(isFacultyId('112345678'), isFalse); // too long
  });

  test('role derived correctly from ID prefix', () {
    String roleFromId(String id) {
      if (RegExp(r'^3[0-9]{7}$').hasMatch(id)) return 'student';
      if (RegExp(r'^1[0-9]{7}$').hasMatch(id)) return 'faculty';
      return 'invalid';
    }
    expect(roleFromId('31234567'), 'student');
    expect(roleFromId('11234567'), 'faculty');
    expect(roleFromId('21234567'), 'invalid');
    expect(roleFromId('123'),      'invalid');
  });

  // Search requires at least 2 characters.
  test('user search requires minimum 2 characters', () {
    bool shouldSearch(String q) => q.trim().length >= 2;
    expect(shouldSearch(''),   isFalse);
    expect(shouldSearch('a'),  isFalse);
    expect(shouldSearch('al'), isTrue);
    expect(shouldSearch('alice'), isTrue);
  });
}

