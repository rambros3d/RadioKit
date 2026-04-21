import 'package:flutter/material.dart';
import 'universal_skin_renderer.dart';
import 'debug_skin_renderer.dart';
import 'skin_renderer.dart';
import '../skin_manager.dart';

/// The high-level entry point for rendering a skinned widget.
/// Now simplified to use the UniversalSkinEngine for all standard skins.
class DynamicSkinRenderer extends StatelessWidget {
  final String widgetFolder;
  final RKSkinState state;
  final String? layer;

  const DynamicSkinRenderer({
    super.key,
    required this.widgetFolder,
    required this.state,
    this.layer,
  });

  @override
  Widget build(BuildContext context) {
    final manifest = SkinManager().current;
    if (manifest == null) return const SizedBox.shrink();

    // Debug skin still uses its hardcoded logic for development
    if (manifest.name == 'debug') {
      return DebugSkinRenderer(widgetFolder: widgetFolder, state: state, layer: layer);
    }

    // All other skins (standard, neon, hybrid) use the universal engine
    return UniversalSkinRenderer(
      widgetFolder: widgetFolder,
      state: state,
      layer: layer,
    );
  }
}

