import 'package:flutter/material.dart';
import 'skin_renderer.dart';
import 'native_skin_renderer.dart';

/// The high-level entry point for rendering a skinned widget.
/// It wraps NativeSkinRenderer now that HTML is deprecated.
class DynamicSkinRenderer extends SkinRenderer {
  const DynamicSkinRenderer({
    super.key,
    required super.widgetFolder,
    required super.state,
    super.layer,
  });

  @override
  Widget build(BuildContext context) {
    return NativeSkinRenderer(
      widgetFolder: widgetFolder,
      state: state,
      layer: layer,
    );
  }
}

