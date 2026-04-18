import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'skin_renderer.dart';
import '../skin_manager.dart';
import 'svg_loader.dart';

/// Renders SVG-based skins. Automatically handles Asset vs Local File resolution.
class NativeSkinRenderer extends SkinRenderer {
  const NativeSkinRenderer({
    super.key,
    required super.widgetFolder,
    required super.state,
  });

  @override
  Widget build(BuildContext context) {
    final manager = SkinManager();
    final manifest = manager.current;
    if (manifest == null) return const SizedBox.shrink();

    final style = manifest.tokens.styles[state.styleIndex] ?? 
                  manifest.tokens.styles[0]!;
    
    final activeColor = state.colorOverride ?? style.primary;

    return FutureBuilder<String?>(
      future: manager.resolveAsset(widgetFolder, _getAssetName()),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final path = snapshot.data!;
        
        // --- ASSET VS FILE RESOLUTION ---
        final isAsset = !path.startsWith('/') && !path.contains(':');
        
        if (isAsset) {
          return SvgPicture.asset(
            path,
            colorFilter: ColorFilter.mode(activeColor, BlendMode.srcIn),
            fit: BoxFit.contain,
          );
        } else {
          // Cross-platform safe file loading
          return renderSvgFile(
            path,
            color: activeColor,
          );
        }
      },
    );
  }

  String _getAssetName() {
    switch (widgetFolder) {
      case 'button_push':
        return state.isPressed ? 'active.svg' : 'bg.svg';
      case 'button_toggle':
        return state.isOn ? 'on.svg' : 'off.svg';
      case 'switch':
        return 'track.svg';
      case 'slider':
        return 'track.svg';
      case 'led':
        return 'base.svg';
      case 'multiple_button':
      case 'multiple_select':
        return 'item.svg';
      default:
        return 'bg.svg';
    }
  }
}
