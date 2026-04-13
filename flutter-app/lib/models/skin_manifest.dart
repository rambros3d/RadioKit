import 'package:flutter/material.dart';

class SkinTokens {
  final Map<String, Color> colors;
  final String fontFamily;
  final String fontWeight;
  final double borderRadius;
  final double borderWidth;

  const SkinTokens({
    this.colors = const {},
    this.fontFamily = 'Inter',
    this.fontWeight = '400',
    this.borderRadius = 8.0,
    this.borderWidth = 1.0,
  });

  factory SkinTokens.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> c = json['colors'] ?? {};
    final Map<String, dynamic> t = json['typography'] ?? {};
    final Map<String, dynamic> s = json['shapes'] ?? {};

    final parsedColors = <String, Color>{};
    c.forEach((key, value) {
      if (value is String && value.startsWith('#')) {
        int colorInt = int.tryParse(value.substring(1), radix: 16) ?? 0;
        if (value.length == 7) {
          colorInt |= 0xFF000000;
        }
        parsedColors[key] = Color(colorInt);
      }
    });

    return SkinTokens(
      colors: parsedColors,
      fontFamily: t['fontFamily']?.toString() ?? 'Inter',
      fontWeight: t['fontWeight']?.toString() ?? '400',
      borderRadius: (s['borderRadius'] as num?)?.toDouble() ?? 8.0,
      borderWidth: (s['borderWidth'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class SkinManifest {
  final String name;
  final String version;
  final String author;
  final SkinTokens tokens;

  const SkinManifest({
    required this.name,
    required this.version,
    required this.author,
    required this.tokens,
  });

  factory SkinManifest.fromJson(Map<String, dynamic> json) {
    return SkinManifest(
      name: json['name']?.toString() ?? 'unknown',
      version: json['version']?.toString() ?? '1.0.0',
      author: json['author']?.toString() ?? 'unknown',
      tokens: SkinTokens.fromJson(json['tokens'] ?? {}),
    );
  }
}
