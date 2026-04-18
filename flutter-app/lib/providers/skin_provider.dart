import 'package:flutter/material.dart';
import '../theme/skin/skin_manager.dart';
import '../theme/skin/skin_tokens.dart';

/// The UI-facing provider that connects the app state to the SkinManager.
class SkinProvider extends ChangeNotifier {
  final SkinManager _skinManager = SkinManager();

  SkinProvider() {
    _skinManager.addListener(_onManagerUpdate);
  }

  @override
  void dispose() {
    _skinManager.removeListener(_onManagerUpdate);
    super.dispose();
  }

  void _onManagerUpdate() {
    notifyListeners();
  }

  /// Initialized the SkinManager. Should be called at app startup.
  Future<void> init() async {
    await _skinManager.init();
  }

  /// The currently active skin's manifest.
  SkinManifest? get currentSkin => _skinManager.current;

  /// The currently active skin's tokens for simple styling outside the renderer.
  SkinTokens? get tokens => _skinManager.current?.tokens;
  
  /// The currently active skin's name.
  String get skinName => _skinManager.activeSkinName;

  /// Switches the active skin.
  Future<void> setSkin(String themeIdentifier) async {
    await _skinManager.applySkin(themeIdentifier);
  }

  /// Triggers the sideload import flow.
  Future<void> importSkin() async {
    final success = await _skinManager.importSkin();
    if (success) {
      debugPrint('SkinProvider: New skin imported successfully.');
    }
  }
}
