import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'skin_tokens.dart';
import 'behavior_config.dart';

/// The central hub for resolving skin assets and configurations.
/// Unified Version: Handles Assets, Local Storage, and Sideloading.
class SkinManager extends ChangeNotifier {
  static final SkinManager _instance = SkinManager._internal();
  factory SkinManager() => _instance;
  SkinManager._internal();

  static const String _skinsDirName = 'skins';
  String? _localSkinsPath;

  SkinManifest? _currentManifest;
  String _activeSkinName = 'default';
  bool _isLocal = false; // Whether current skin is from local storage

  final Map<String, BehaviorConfig> _configCache = {};
  final Map<String, SkinManifest> _manifestCache = {};

  SkinManifest? get current => _currentManifest;
  String get activeSkinName => _activeSkinName;

  /// Initializes the skin engine and local storage paths.
  Future<void> init() async {
    if (!kIsWeb) {
      try {
        final appDocs = await getApplicationDocumentsDirectory();
        final skinsDir = Directory(p.join(appDocs.path, _skinsDirName));
        if (!await skinsDir.exists()) {
          await skinsDir.create(recursive: true);
        }
        _localSkinsPath = skinsDir.path;
        await _loadLocalManifests();
      } catch (e) {
        debugPrint('SkinManager: Local storage init error: $e');
      }
    }
    
    // Default to the built-in 'default' skin
    await applySkin('default');
  }

  Future<void> _loadLocalManifests() async {
    if (_localSkinsPath == null) return;
    final dir = Directory(_localSkinsPath!);
    if (!await dir.exists()) return;

    final entities = dir.listSync();
    for (var entity in entities) {
      if (entity is Directory) {
        final mFile = File(p.join(entity.path, 'manifest.json'));
        if (await mFile.exists()) {
          try {
            final content = await mFile.readAsString();
            final manifest = SkinManifest.fromJson(jsonDecode(content));
            _manifestCache[manifest.name] = manifest;
          } catch (_) {}
        }
      }
    }
  }

  /// Switches the active skin.
  Future<void> applySkin(String skinName) async {
    _configCache.clear();
    _activeSkinName = skinName;

    // 1. Check Local Storage first (User Imported)
    if (_manifestCache.containsKey(skinName)) {
      _currentManifest = _manifestCache[skinName];
      _isLocal = true;
      notifyListeners();
      return;
    }

    // 2. Check Assets (Built-in)
    try {
      final path = 'resources/skins/$skinName/manifest.json';
      final json = await rootBundle.loadString(path);
      _currentManifest = SkinManifest.fromJson(jsonDecode(json));
      _isLocal = false;
    } catch (e) {
      debugPrint('SkinManager: Skin $skinName not found. Reverting to default.');
      if (skinName != 'default') await applySkin('default');
    }
    notifyListeners();
  }

  /// Resolves an asset path or file for a widget.
  /// Returns a 'String' that is either an asset path or a local file path.
  Future<String?> resolveAsset(String widgetFolder, String assetName) async {
    if (_isLocal && _localSkinsPath != null) {
      final localPath = p.join(_localSkinsPath!, _activeSkinName, widgetFolder, assetName);
      if (await File(localPath).exists()) return localPath;
    }

    // Asset Fallback
    final assetPath = 'resources/skins/$_activeSkinName/$widgetFolder/$assetName';
    if (await _assetExists(assetPath)) return assetPath;

    // Global 'Default' Fallback
    if (_activeSkinName != 'default') {
      final defPath = 'resources/skins/default/$widgetFolder/$assetName';
      if (await _assetExists(defPath)) return defPath;
    }

    return null;
  }

  /// Specialized helper for text-based assets (HTML/CSS/JSON)
  Future<String?> loadString(String widgetFolder, String fileName) async {
    final path = await resolveAsset(widgetFolder, fileName);
    if (path == null) return null;

    final bool assumedAsset = !path.startsWith('/') && !path.contains(':'); 
    // On native, local paths are absolute. Assets are relative.

    if (assumedAsset) {
      return rootBundle.loadString(path);
    } else {
      return File(path).readAsString();
    }
  }

  Future<BehaviorConfig> getWidgetConfig(String widgetFolder) async {
    if (_configCache.containsKey(widgetFolder)) return _configCache[widgetFolder]!;

    final jsonStr = await loadString(widgetFolder, 'config.json');
    if (jsonStr != null) {
      final config = BehaviorConfig.fromJson(jsonDecode(jsonStr));
      _configCache[widgetFolder] = config;
      return config;
    }
    
    return BehaviorConfig.empty();
  }

  Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Sideloading Logic (Importing .rkskin ZIPs)
  Future<bool> importSkin() async {
    if (kIsWeb || _localSkinsPath == null) return false;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['rkskin', 'zip'],
      );

      if (result != null && result.files.single.path != null) {
        final bytes = await File(result.files.single.path!).readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);
        
        // Find manifest to get name
        String? skinName;
        for (final file in archive) {
          if (file.name == 'manifest.json') {
            final json = jsonDecode(utf8.decode(file.content as List<int>));
            skinName = json['name'];
            break;
          }
        }

        if (skinName == null) return false;

        final targetDir = Directory(p.join(_localSkinsPath!, skinName));
        if (await targetDir.exists()) await targetDir.delete(recursive: true);
        await targetDir.create(recursive: true);

        for (final file in archive) {
          if (file.isFile) {
            final outFile = File(p.join(targetDir.path, file.name));
            await outFile.create(recursive: true);
            await outFile.writeAsBytes(file.content as List<int>);
          }
        }

        await _loadLocalManifests();
        return true;
      }
    } catch (e) {
      debugPrint('SkinManager: Import error: $e');
    }
    return false;
  }
}
