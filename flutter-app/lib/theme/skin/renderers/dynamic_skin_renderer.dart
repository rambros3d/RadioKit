import 'package:flutter/material.dart';
import 'skin_renderer.dart';
import 'native_skin_renderer.dart';
import 'debug_skin_renderer.dart';
import '../skin_manager.dart';

/// The high-level entry point for rendering a skinned widget.
class DynamicSkinRenderer extends SkinRenderer {
  const DynamicSkinRenderer({
    super.key,
    required super.widgetFolder,
    required super.state,
    super.layer,
  });

  @override
  Widget build(BuildContext context) {
    final manager = SkinManager();
    final skinName = manager.activeSkinName;

    if (skinName == 'debug') {
      return DebugSkinRenderer(
        widgetFolder: widgetFolder,
        state: state,
        layer: layer,
      );
    }

    return NativeSkinRenderer(
      widgetFolder: widgetFolder,
      state: state,
      layer: layer,
    );
  }
}

