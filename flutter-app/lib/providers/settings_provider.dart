import 'dart:convert';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages runtime application settings that cannot be configured via compile-time macros.
class SettingsProvider with ChangeNotifier {
  static const _storageKey = 'radiokit_settings';
  static const _defaultShowDemo = true;

  bool _showDemo = _defaultShowDemo;

  bool get showDemo => _showDemo;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> setShowDemo(bool value) async {
    if (_showDemo != value) {
      _showDemo = value;
      notifyListeners();
      await _persist();
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data != null) {
        final decoded = Map<String, dynamic>.from(jsonDecode(data));
        _showDemo = decoded['showDemo'] ?? _defaultShowDemo;
      }
    } catch (e) {
      debugPrint('RadioKit: Failed to load settings: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode({
        'showDemo': _showDemo,
      });
      await prefs.setString(_storageKey, data);
    } catch (e) {
      debugPrint('RadioKit: Failed to persist settings: $e');
    }
  }
}