import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final notificationSoundEnabledProvider =
    StateNotifierProvider<NotificationSoundNotifier, bool>((ref) {
  return NotificationSoundNotifier();
});

class NotificationSoundNotifier extends StateNotifier<bool> {
  NotificationSoundNotifier() : super(true) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('notification_sound_enabled') ?? true;
      state = enabled;
    } catch (_) {}
  }

  Future<void> toggleSound(bool enabled) async {
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notification_sound_enabled', enabled);
    } catch (_) {}
  }
}

class NotificationSoundService {
  /// Plays a distinct notification chime sound & vibration feedback across platforms
  static Future<void> playNotificationSound({bool soundEnabled = true}) async {
    if (!soundEnabled) return;

    try {
      // Trigger native system sound & vibration
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint("Error playing notification sound: $e");
    }
  }
}
