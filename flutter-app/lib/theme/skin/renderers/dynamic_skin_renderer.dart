import 'package:flutter/material.dart';
import 'skin_renderer.dart';
import 'native_skin_renderer.dart';
import 'html_skin_renderer.dart';
import '../skin_manager.dart';

/// The high-level entry point for rendering a skinned widget.
/// It automatically chooses the best renderer (HTML > Native > Default)
/// according to the v1.6 Mixed-Mode discovery logic.
class DynamicSkinRenderer extends SkinRenderer {
  const DynamicSkinRenderer({
    super.key,
    required super.widgetFolder,
    required super.state,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasHtml(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final useHtml = snapshot.data!;

        if (useHtml) {
          return HtmlSkinRenderer(
            widgetFolder: widgetFolder,
            state: state,
          );
        } else {
          return NativeSkinRenderer(
            widgetFolder: widgetFolder,
            state: state,
          );
        }
      },
    );
  }

  Future<bool> _hasHtml() async {
    final manager = SkinManager();
    final htmlPath = await manager.resolveAsset(widgetFolder, 'widget.html');
    return htmlPath != null;
  }
}
