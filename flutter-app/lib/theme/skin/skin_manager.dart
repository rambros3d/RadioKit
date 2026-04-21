import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String _activeSkinName = 'standard';
  bool _isLocal = false; // Whether current skin is from local storage

  static const String _prefsKey = 'active_skin';
  static const List<String> _builtInSkins = ['standard', 'neon', 'debug'];

  final Map<String, BehaviorConfig> _configCache = {};
  final Map<String, SkinManifest> _manifestCache = {};
  AssetManifest? _assetManifest;

  SkinManifest? get current => _currentManifest;
  String get activeSkinName => _activeSkinName;

  /// Initializes the skin engine and local storage paths.
  Future<void> init() async {
    _assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    
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
    
    // Restore previously active skin, or fall back to 'default'
    String skinName = 'standard';
    try {
      final prefs = await SharedPreferences.getInstance();
      skinName = prefs.getString(_prefsKey) ?? 'standard';
    } catch (_) {}
    await applySkin(skinName);
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

  /// Switches the active skin and persists the choice.
  Future<void> applySkin(String skinName) async {
    _configCache.clear();
    _activeSkinName = skinName;

    // 1. Check Local Storage first (User Imported)
    if (_manifestCache.containsKey(skinName)) {
      _currentManifest = _manifestCache[skinName];
      _isLocal = true;
      _persistSkinChoice(skinName);
      notifyListeners();
      return;
    }

    // 2. Check Assets (Built-in)
    try {
      final path = 'resources/skins/$skinName/manifest.json';
      final json = await rootBundle.loadString(path);
      _currentManifest = SkinManifest.fromJson(jsonDecode(json));
      _isLocal = false;
      _persistSkinChoice(skinName);
    } catch (e) {
      debugPrint('SkinManager: Skin $skinName not found. Reverting to default.');
      if (skinName != 'standard') await applySkin('standard');
    }
    notifyListeners();
  }

  void _persistSkinChoice(String name) {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_prefsKey, name);
    }).catchError((_) {});
  }

  /// Resolves an asset for a widget using its decentralized config.json.
  Future<String?> resolveWidgetAsset(
    String widgetFolder,
    String stateOrLayerKey,
  ) async {
    final config = await getWidgetConfig(widgetFolder);
    final relativePath = config.states[stateOrLayerKey] ??
                        config.layers[stateOrLayerKey];

    if (relativePath != null) {
      // Logic: If the path is just a file name (e.g. "base.svg"),
      // we prepend the widget folder to make it relative to the skin root.
      final fullRelativePath = p.join(widgetFolder, relativePath);
      return _resolveManifestPath(fullRelativePath);
    }
    return null;
  }

  /// Resolves a path declared in the manifest (relative to skin root).
  Future<String?> _resolveManifestPath(String relativePath) async {
    if (_isLocal && _localSkinsPath != null) {
      final localPath = p.join(_localSkinsPath!, _activeSkinName, relativePath);
      if (await File(localPath).exists()) return localPath;
    }
    final assetPath = 'resources/skins/$_activeSkinName/$relativePath';
    if (await _assetExists(assetPath)) return assetPath;
    return null;
  }

  /// Resolves an asset path or file for a widget (convention-based).
  Future<String?> resolveAsset(String widgetFolder, String assetName) async {
    if (_isLocal && _localSkinsPath != null) {
      final localPath = p.join(_localSkinsPath!, _activeSkinName, widgetFolder, assetName);
      if (await File(localPath).exists()) return localPath;
    }

    // Asset Fallback
    final assetPath = 'resources/skins/$_activeSkinName/$widgetFolder/$assetName';
    if (await _assetExists(assetPath)) return assetPath;

    // Global 'Standard' Fallback
    if (_activeSkinName != 'standard') {
      final defPath = 'resources/skins/standard/$widgetFolder/$assetName';
      if (await _assetExists(defPath)) return defPath;
    }

    return null;
  }

  /// Loads a string from an asset or local file.
  Future<String?> loadString(String widgetFolder, String fileName) async {
    final path = await resolveAsset(widgetFolder, fileName);
    if (path == null) return null;

    final bool assumedAsset = !path.startsWith('/') && !path.contains(':'); 

    if (assumedAsset) {
      return rootBundle.loadString(path);
    } else {
      return File(path).readAsString();
    }
  }

  /// Fetches the BehaviorConfig (asset mapping + physics) for a widget.
  Future<BehaviorConfig> getWidgetConfig(String widgetFolder) async {
    if (_configCache.containsKey(widgetFolder)) return _configCache[widgetFolder]!;

    final jsonStr = await loadString(widgetFolder, 'config.json');
    if (jsonStr != null) {
      try {
        final config = BehaviorConfig.fromJson(jsonDecode(jsonStr));
        _configCache[widgetFolder] = config;
        return config;
      } catch (e) {
        debugPrint('SkinManager: Error parsing config.json for $widgetFolder: $e');
      }
    }
    
    return BehaviorConfig.empty();
  }

  /// Lists all available skin names (built-in + imported).
  List<String> listAvailableSkins() {
    final names = <String>{..._builtInSkins};
    names.addAll(_manifestCache.keys);
    return names.toList();
  }

  /// Returns the manifest for a named skin (for the browser UI).
  Future<SkinManifest?> getManifest(String skinName) async {
    if (_manifestCache.containsKey(skinName)) {
      return _manifestCache[skinName];
    }
    try {
      final path = 'resources/skins/$skinName/manifest.json';
      final json = await rootBundle.loadString(path);
      return SkinManifest.fromJson(jsonDecode(json));
    } catch (_) {
      return null;
    }
  }

  /// Resolves the preview image path for a skin (or null).
  Future<String?> getPreviewPath(String skinName) async {
    if (_localSkinsPath != null) {
      final localPath = p.join(_localSkinsPath!, skinName, 'preview.png');
      if (await File(localPath).exists()) return localPath;
    }
    final assetPath = 'resources/skins/$skinName/preview.png';
    if (await _assetExists(assetPath)) return assetPath;
    return null;
  }

  Future<bool> _assetExists(String path) async {
    // If we have a manifest, check it first to avoid 404s on Web
    if (_assetManifest != null) {
      return _assetManifest!.listAssets().contains(path);
    }

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
