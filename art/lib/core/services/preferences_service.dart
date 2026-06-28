import 'package:flutter/material.dart';
import '../../data/models/story_model.dart';

import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService extends ChangeNotifier {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  late SharedPreferences _prefs;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  // Preference keys
  static const String _keyNotifications = 'notifications_enabled';
  static const String _keyDarkMode = 'dark_mode_enabled';
  static const String _keyPrivateAccount = 'private_account_enabled';
  static const String _keyLanguage = 'selected_language';

  // Current values (cached in memory)
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = true; // Default to black theme
  bool _privateAccountEnabled = false;
  String _language = 'English';

  bool get notificationsEnabled => _notificationsEnabled;
  bool get darkModeEnabled => _darkModeEnabled;
  bool get privateAccountEnabled => _privateAccountEnabled;
  String get language => _language;

  Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();

    _notificationsEnabled = _prefs.getBool(_keyNotifications) ?? true;
    _darkModeEnabled =
        _prefs.getBool(_keyDarkMode) ?? true; // Default to black theme
    _privateAccountEnabled = _prefs.getBool(_keyPrivateAccount) ?? false;
    _language = _prefs.getString(_keyLanguage) ?? 'English';

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    await _prefs.setBool(_keyNotifications, value);
    notifyListeners();
  }

  Future<void> setDarkModeEnabled(bool value) async {
    _darkModeEnabled = value;
    await _prefs.setBool(_keyDarkMode, value);
    notifyListeners();
  }

  Future<void> setPrivateAccountEnabled(bool value) async {
    _privateAccountEnabled = value;
    await _prefs.setBool(_keyPrivateAccount, value);
    notifyListeners();
  }

  Future<void> setLanguage(String value) async {
    _language = value;
    await _prefs.setString(_keyLanguage, value);
    notifyListeners();
  }

  // Story viewed state
  void markStoryViewed(String userId, DateTime createdAt) {
    if (!_isInitialized) return;
    final key = 'story_viewed_$userId';
    final lastViewed = _prefs.getString(key);

    // Only update if the new story is newer than the last viewed
    if (lastViewed != null) {
      final lastViewedDate = DateTime.parse(lastViewed);
      if (createdAt.isBefore(lastViewedDate) ||
          createdAt.isAtSameMomentAs(lastViewedDate)) {
        return;
      }
    }

    _prefs.setString(key, createdAt.toIso8601String());
    notifyListeners();
  }

  bool hasUnviewedStories(String userId, List<StoryModel> stories) {
    if (!_isInitialized || stories.isEmpty) return false;
    final key = 'story_viewed_$userId';
    final lastViewed = _prefs.getString(key);

    if (lastViewed == null)
      return true; // Never viewed any stories from this user

    final lastViewedDate = DateTime.parse(lastViewed);
    // If any story is strictly newer than lastViewedDate, return true
    for (var story in stories) {
      if (story.createdAt.isAfter(lastViewedDate)) return true;
    }
    return false;
  }
}
