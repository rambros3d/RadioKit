import 'package:flutter/material.dart';
import 'native_skin_renderer.dart';
import 'custom_skin_renderer.dart';
import 'debug_skin_renderer.dart';
import 'skin_renderer.dart';
import '../skin_manager.dart';
import '../skin_tokens.dart';

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

    // Debug skin always uses the debug renderer
    if (manifest.name == 'debug') {
      return DebugSkinRenderer(widgetFolder: widgetFolder, state: state, layer: layer);
    }

    // Select engine based on Global Manifest Type
    if (manifest.renderer == SkinRendererType.native) {
      return NativeSkinRenderer(
        widgetFolder: widgetFolder,
        state: state,
        layer: layer,
      );
    }

    return CustomSkinRenderer(
      widgetFolder: widgetFolder,
      state: state,
      layer: layer,
    );
  }
}
