import 'dart:ui';

/// Data class representing a style override from the manifest 'styles' map.
class SkinStyle {
  final Color primary;
  final bool glow;

  SkinStyle({required this.primary, this.glow = false});

  factory SkinStyle.fromJson(Map<String, dynamic> json) {
    return SkinStyle(
      primary: Color(int.parse(json['primary'].replaceAll('#', '0xFF'))),
      glow: json['glow'] ?? false,
    );
  }
}

/// Core visual tokens for a Skin.
class SkinTokens {
  final Map<String, Color> colors;
  final Map<String, dynamic> effects;
  final Map<String, String> typography;
  final Map<String, double> shapes;
  final Map<int, SkinStyle> styles;

  SkinTokens({
    required this.colors,
    required this.effects,
    required this.typography,
    required this.shapes,
    required this.styles,
  });

  factory SkinTokens.fromJson(Map<String, dynamic> json) {
    // Parse Colors
    final colorsMap = (json['colors'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, Color(int.parse(value.replaceAll('#', '0xFF')))),
    );

    // Parse Styles (Map keys are strings "0".."4", convert to int)
    final stylesMap = (json['styles'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(int.parse(key), SkinStyle.fromJson(value)),
    );

    return SkinTokens(
      colors: colorsMap,
      effects: json['effects'] ?? {},
      typography: (json['typography'] as Map<String, dynamic>).cast<String, String>(),
      shapes: (json['shapes'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v.toDouble())),
      styles: stylesMap,
    );
  }
}

/// The root Manifest object.
class SkinManifest {
  final String name;
  final String version;
  final String author;
  final String? description;
  final String? preview;
  final SkinTokens tokens;

  /// App-wide color overrides (accent, background, grid).
  final Map<String, Color> colors;

  SkinManifest({
    required this.name,
    required this.version,
    required this.author,
    this.description,
    this.preview,
    required this.tokens,
    this.colors = const {},
  });

  factory SkinManifest.fromJson(Map<String, dynamic> json) {
    // Parse app-wide colors (v2 manifests)
    final colorsMap = <String, Color>{};
    if (json['colors'] is Map<String, dynamic>) {
      (json['colors'] as Map<String, dynamic>).forEach((key, value) {
        if (value is String && value.startsWith('#')) {
          colorsMap[key] = Color(int.parse(value.replaceAll('#', '0xFF')));
        }
      });
    }

    return SkinManifest(
      name: json['name'],
      version: json['version'],
      author: json['author'],
      description: json['description'],
      preview: json['preview'],
      tokens: SkinTokens.fromJson(json['tokens']),
      colors: colorsMap,
    );
  }
}
