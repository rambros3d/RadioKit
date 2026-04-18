import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'skin_renderer.dart';
import '../skin_manager.dart';
import 'svg_loader.dart';

/// Renders SVG-based skins. Uses manifest-driven asset resolution
/// with convention-based fallback for backward compatibility.
class NativeSkinRenderer extends SkinRenderer {
  const NativeSkinRenderer({
    super.key,
    required super.widgetFolder,
    required super.state,
    super.layer,
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
      future: manager.resolveWidgetAsset(
        widgetFolder,
        layer ?? _stateKey(),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final path = snapshot.data!;
        
        // --- ASSET VS FILE RESOLUTION ---
        final isAsset = !path.startsWith('/') && !path.contains(':');
        
        // Premium Skin Tinting Logic: 
        // Only tint "dynamic" semantic layers. Keep bases/backgrounds/textured buttons original.
        bool shouldTint = false;
        if (widgetFolder == 'led' && (layer == 'on' || state.isOn)) {
          shouldTint = true;
        } else if (layer == 'indicator' || layer == 'thumb' || layer == 'stick') {
          shouldTint = true;
        } else if (widgetFolder == 'multiple_button' && layer == 'active') {
          shouldTint = true;
        }

        if (isAsset) {
          return SvgPicture.asset(
            path,
            colorFilter: shouldTint 
              ? ColorFilter.mode(activeColor, BlendMode.srcIn)
              : null,
            fit: BoxFit.contain,
          );
        } else {
          // Cross-platform safe file loading
          return renderSvgFile(
            path,
            color: shouldTint ? activeColor : null,
          );
        }
      },
    );
  }

  /// Returns the semantic state key for manifest lookup.
  String _stateKey() {
    switch (widgetFolder) {
      case 'button_push':
        return state.isPressed ? 'pressed' : 'idle';
      case 'button_toggle':
        return state.isOn ? 'on' : 'off';
      case 'switch':
        return state.isOn ? 'on' : 'off';
      case 'display':
        return 'background';
      case 'led':
        return state.isOn ? 'on' : 'base';
      case 'multiple_button':
      case 'multiple_select':
        return state.isOn ? 'active' : 'idle';
      default:
        return state.isPressed ? 'pressed' : 'idle';
    }
  }
}
