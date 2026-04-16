import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../models/skin_manifest.dart';

class SkinManager {
  static const String _skinsDirName = 'skins';
  String? _localSkinsPath;

  /// Holds cached manifests for quick lookup
  final Map<String, SkinManifest> _manifestCache = {};

  Future<void> init() async {
    if (kIsWeb) {
      // Local file system operations not supported on web
      return;
    }
    
    try {
      final appDocs = await getApplicationDocumentsDirectory();
      final skinsDir = Directory(p.join(appDocs.path, _skinsDirName));
      if (!await skinsDir.exists()) {
        await skinsDir.create(recursive: true);
      }
      _localSkinsPath = skinsDir.path;
      debugPrint('SkinManager initialized. Local skins path: $_localSkinsPath');
      await _loadLocalSkins();
    } catch (e) {
      debugPrint('SkinManager init error: $e');
    }
  }

  Future<void> _loadLocalSkins() async {
    if (_localSkinsPath == null) return;
    
    final dir = Directory(_localSkinsPath!);
    if (!await dir.exists()) return;

    final entities = dir.listSync();
    for (var entity in entities) {
      if (entity is Directory) {
        final manifestPath = p.join(entity.path, 'manifest.json');
        final manifestFile = File(manifestPath);
        if (await manifestFile.exists()) {
          try {
            final content = await manifestFile.readAsString();
            final json = jsonDecode(content);
            final manifest = SkinManifest.fromJson(json);
            _manifestCache[manifest.name] = manifest;
            debugPrint('Loaded local skin: ${manifest.name}');
          } catch (e) {
            debugPrint('Failed to load skin from ${entity.path}: $e');
          }
        }
      }
    }
  }

  /// Resolve a skin by name. First checks local storage, then built-in assets.
  Future<SkinManifest?> getSkin(String skinName) async {
    // 1. Check local cache (Sideloaded skins)
    if (_manifestCache.containsKey(skinName)) {
      return _manifestCache[skinName];
    }

    // 2. Fallback to Asset Built-in Skins
    try {
      final assetPath = 'assets/skins/$skinName/manifest.json';
      final manifestStr = await rootBundle.loadString(assetPath);
      final json = jsonDecode(manifestStr);
      final manifest = SkinManifest.fromJson(json);
      _manifestCache[manifest.name] = manifest;
      return manifest;
    } catch (e) {
      debugPrint('Built-in skin "$skinName" not found or invalid: $e');
    }

    return null;
  }

  /// Opens a file picker, unzips a .rkskin file, and extracts it to the local library.
  Future<bool> sideloadSkin() async {
    if (kIsWeb) {
      debugPrint('Sideloading not supported on the web');
      return false;
    }

    if (_localSkinsPath == null) {
      debugPrint('Local skins path not initialized');
      return false;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['rkskin', 'zip'],
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final bytes = await File(filePath).readAsBytes();
        
        final archive = ZipDecoder().decodeBytes(bytes);
        
        // Find manifest.json to get the skin name before extraction
        ArchiveFile? manifestFile;
        for (final file in archive) {
          if (file.name == 'manifest.json') {
            manifestFile = file;
            break;
          }
        }

        if (manifestFile == null) {
          debugPrint('Invalid skin pack: manifest.json not found');
          return false;
        }

        final manifestContent = utf8.decode(manifestFile.content as List<int>);
        final manifestJson = jsonDecode(manifestContent);
        final skinName = manifestJson['name'] as String?;

        if (skinName == null || skinName.isEmpty) {
          debugPrint('Invalid skin pack: no name in manifest.json');
          return false;
        }

        // Extract to a folder based on the skin name
        final targetDir = Directory(p.join(_localSkinsPath!, skinName));
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }

        for (final file in archive) {
          final filename = file.name;
          if (file.isFile) {
            final data = file.content as List<int>;
            final outFile = File(p.join(targetDir.path, filename));
            await outFile.create(recursive: true);
            await outFile.writeAsBytes(data);
          } else {
            Directory(p.join(targetDir.path, filename)).createSync(recursive: true);
          }
        }

        debugPrint('Successfully extracted skin: $skinName');
        await _loadLocalSkins(); // Reload cache
        return true;
      }
    } catch (e) {
      debugPrint('Error sideloading skin: $e');
    }
    return false;
  }
}
