import 'package:flutter/material.dart';
import '../models/skin_manifest.dart';
import '../services/skin_manager.dart';

class SkinProvider extends ChangeNotifier {
  final SkinManager _skinManager;
  SkinManifest? _currentSkin;

  SkinProvider(this._skinManager);

  /// The currently active skin's design tokens. Falls back to default if no skin is active.
  SkinTokens get tokens => _currentSkin?.tokens ?? const SkinTokens();
  
  /// The currently active skin's name.
  String get skinName => _currentSkin?.name ?? 'default';
  
  /// Whether a custom skin is currently applied.
  bool get hasSkin => _currentSkin != null;

  /// Fetch and apply a new skin by its identifier string (e.g. from CONF_DATA)
  Future<void> setSkin(String themeIdentifier) async {
    if (themeIdentifier.isEmpty) {
      themeIdentifier = 'default';
    }

    // Don't re-parse if it's already the active skin
    if (_currentSkin?.name == themeIdentifier) {
      return;
    }

    final manifest = await _skinManager.getSkin(themeIdentifier);
    
    if (manifest != null) {
      _currentSkin = manifest;
      debugPrint('SkinProvider: Applied skin "${manifest.name}"');
    } else {
      debugPrint('SkinProvider: Failed to load skin "$themeIdentifier", falling back to default');
      // If we failed to find the requested one, try to apply "default" if not already applying it.
      if (themeIdentifier != 'default') {
        final defaultManifest = await _skinManager.getSkin('default');
        _currentSkin = defaultManifest;
      } else {
        _currentSkin = null;
      }
    }
    
    notifyListeners();
  }

  /// Triggers a sideload flow and applies the skin if successful.
  Future<void> importSkin() async {
    final success = await _skinManager.sideloadSkin();
    if (success) {
      debugPrint('SkinProvider: Skin imported successfully.');
      // The user would typically select it manually, or we could automatically 
      // apply the most recently imported one. For now, we just let the UI know 
      // the library changed if we had a library screen.
      notifyListeners();
    }
  }
}
