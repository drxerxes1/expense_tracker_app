import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const String _keyIsFirstTime = 'is_first_time_user';

  /// Check if this is the user's first time opening the app
  static Future<bool> isFirstTimeUser() async {
    final prefs = await SharedPreferences.getInstance();
    // Returns true if key doesn't exist or value is true
    return prefs.getBool(_keyIsFirstTime) ?? true;
  }

  /// Mark that the user has completed or skipped onboarding
  static Future<void> setOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsFirstTime, false);
  }

  /// Reset onboarding (useful for testing)
  static Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsFirstTime);
  }
}
