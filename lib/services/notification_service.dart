import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_client.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  /// Call once in main() — pass your OneSignal App ID from .env
  Future<void> initialize(String oneSignalAppId) async {
    // Enable verbose logging during development (remove in production)
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

    OneSignal.initialize(oneSignalAppId);

    // Ask user for notification permission
    await OneSignal.Notifications.requestPermission(true);

    // When a notification is opened, you can navigate here
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      print('Notification tapped: $data');
      // TODO: navigate based on data['type'] if needed
    });

    // Save OneSignal player ID to Supabase so Edge Function can target users
    await _savePlayerId();

    // Update player ID whenever it changes
    OneSignal.User.pushSubscription.addObserver((state) {
      final id = state.current.id;
      if (id != null) _uploadPlayerId(id);
    });
  }

  Future<void> _savePlayerId() async {
    final id = OneSignal.User.pushSubscription.id;
    if (id != null) {
      await _uploadPlayerId(id);
    }
    // Also listen for auth state changes — upload token when user logs in
    supabase.auth.onAuthStateChange.listen((data) async {
      if (data.session != null) {
        final currentId = OneSignal.User.pushSubscription.id;
        if (currentId != null) {
          await _uploadPlayerId(currentId);
        }
        await uploadPendingToken();
      }
    });
  }

  Future<void> _uploadPlayerId(String playerId) async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        // Save locally, upload after login
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_onesignal_id', playerId);
        return;
      }
      await supabase.from('user_push_tokens').upsert({
        'user_id': uid,
        'player_id': playerId,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      print('Error saving OneSignal player ID: $e');
    }
  }

  /// Call after login to upload the OneSignal token now that user is authenticated
  Future<void> uploadPendingToken() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Tell OneSignal which Supabase user this device belongs to
    OneSignal.login(userId);

    // Always try the live subscription ID first
    final liveId = OneSignal.User.pushSubscription.id;
    if (liveId != null) {
      await _uploadPlayerId(liveId);
    }
    // Also upload any token saved before login
    final prefs = await SharedPreferences.getInstance();
    final pendingId = prefs.getString('pending_onesignal_id');
    if (pendingId != null && pendingId != liveId) {
      await _uploadPlayerId(pendingId);
    }
    await prefs.remove('pending_onesignal_id');
  }

  /// Send a push notification via Supabase Edge Function
  /// Call this after posting announcements, events, messages, resources
  static Future<void> send({
    required String type,       // 'announcement' | 'event' | 'chat' | 'resource'
    required String title,
    required String body,
    String? excludeUserId,      // don't notify the sender
  }) async {
    try {
      await supabase.functions.invoke('send-notification', body: {
        'type': type,
        'title': title,
        'body': body,
        if (excludeUserId != null) 'excludeUserId': excludeUserId,
      });
    } catch (e) {
      print('Error sending notification: $e');
    }
  }
}
