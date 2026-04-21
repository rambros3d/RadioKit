import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'skin_renderer.dart';
import '../skin_manager.dart';
import '../skin_tokens.dart';
import '../behavior_config.dart' as cfg;

/// Renderer for SVG-based skins (e.g. Standard).
/// Composes multiple SVG layers driven by live state values (rotation, translation, clipping).
class CustomSkinRenderer extends SkinRenderer {
  const CustomSkinRenderer({
    super.key,
    required super.widgetFolder,
    required super.state,
    super.layer,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<cfg.BehaviorConfig>(
      future: SkinManager().getWidgetConfig(widgetFolder),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final config = snapshot.data!;
        final manifest = SkinManager().current;
        if (manifest == null) return const SizedBox.shrink();

        // Fail-safe: If we are in a native skin, CustomSkinRenderer should NOT run.
        if (manifest.renderer == SkinRendererType.native || manifest.name == 'neon') {
          return const SizedBox.shrink();
        }

        return _buildComposition(context, manifest, config);
      },
    );
  }

  Widget _buildComposition(BuildContext context, SkinManifest manifest, cfg.BehaviorConfig config) {
    // Role-based selection for sub-components (MultipleWidget items, etc.)
    if (layer != null) {
       final assetPath = config.layers[layer];
       if (assetPath != null) return _renderLayer(assetPath, manifest);
       return const SizedBox.shrink();
    }

    switch (widgetFolder) {
      case 'button_push':
      case 'multiple_button':
        if (config.layers.isEmpty) return const SizedBox.shrink();
        return _renderButton(manifest, config);
      case 'joystick':
        if (config.layers.isEmpty) return const SizedBox.shrink();
        return _renderJoystick(manifest, config);
      case 'slider':
        if (config.layers.isEmpty) return const SizedBox.shrink();
        return _renderSlider(manifest, config);
      case 'knob':
        if (config.layers.isEmpty) return const SizedBox.shrink();
        return _renderKnob(manifest, config);
      case 'led':
        if (config.layers.isEmpty) return const SizedBox.shrink();
        return _renderLed(manifest, config);
      case 'toggle_switch':
      case 'button_toggle':
        if (config.layers.isEmpty) return const SizedBox.shrink();
        return _renderToggleSwitch(manifest, config);
      default:
        // Generic fallback: render 'base' or first available layer
        final base = config.layers['base'] ?? (config.layers.isNotEmpty ? config.layers.values.first : null);
        return base != null ? _renderLayer(base, manifest) : const SizedBox.shrink();
    }
  }

  // --- Widget Specialized Renderers ---

  Widget _renderButton(SkinManifest manifest, cfg.BehaviorConfig config) {
    final bool pressed = state.isPressed;
    final String layerKey = pressed ? (config.layers.containsKey('pressed') ? 'pressed' : 'idle') : 'idle';
    final assetPath = config.layers[layerKey] ?? (config.layers.isNotEmpty ? config.layers.values.first : '');
    
    if (assetPath.isEmpty) return const SizedBox.shrink();

    final bool isGlowEnabled = config.effects['glow_states']?.contains(pressed ? 'pressed' : 'idle') ?? false;
    final double glowIntensity = isGlowEnabled ? (config.animations['press']?.glowBoost ?? 1.2) : 1.0;

    return _renderLayer(assetPath, manifest, glow: glowIntensity);
  }

  Widget _renderJoystick(SkinManifest manifest, cfg.BehaviorConfig config) {
    final baseAsset = config.layers['base'];
    final stickAsset = config.layers['stick'];
    
    final travel = (config.stick?['travel'] ?? 0.35).toDouble();
    
    return Stack(
      children: [
        if (baseAsset != null) _renderLayer(baseAsset, manifest),
        if (stickAsset != null)
          LayoutBuilder(builder: (context, constraints) {
            final side = constraints.maxWidth;
            return Transform.translate(
              offset: Offset(state.valueX * side * travel, state.valueY * side * travel),
              child: _renderLayer(stickAsset, manifest),
            );
          }),
      ],
    );
  }

  Widget _renderSlider(SkinManifest manifest, cfg.BehaviorConfig config) {
    final trackAsset = config.layers['track'];
    final fillAsset = config.layers['fill'];
    final thumbAsset = config.layers['thumb'];

    final axis = config.fill?['axis'] ?? 'horizontal';
    final bool isHorizontal = axis == 'horizontal';

    return Stack(
      children: [
        if (trackAsset != null) _renderLayer(trackAsset, manifest),
        if (fillAsset != null)
          ClipRect(
            clipper: _RelativeClipper(value: state.value, isHorizontal: isHorizontal),
            child: _renderLayer(fillAsset, manifest),
          ),
        if (thumbAsset != null)
           _PositionedAcrossAxis(
             value: state.value,
             isHorizontal: isHorizontal,
             child: _renderLayer(thumbAsset, manifest),
           ),
      ],
    );
  }

  Widget _renderKnob(SkinManifest manifest, cfg.BehaviorConfig config) {
    final bodyAsset = config.layers['body'];
    final indicatorAsset = config.layers['indicator'];

    final rotationCfg = config.indicator?['rotation'] ?? {};
    final double minDeg = (rotationCfg['min_degrees'] ?? -135).toDouble();
    final double maxDeg = (rotationCfg['max_degrees'] ?? 135).toDouble();
    final List<dynamic> pivot = rotationCfg['pivot'] ?? [0.5, 0.5];

    final double rotation = minDeg + (state.value * (maxDeg - minDeg));

    return Stack(
      children: [
        if (bodyAsset != null) _renderLayer(bodyAsset, manifest),
        if (indicatorAsset != null)
           Transform.rotate(
             angle: rotation * 3.14159265359 / 180,
             alignment: Alignment(pivot[0] * 2 - 1, pivot[1] * 2 - 1),
             child: _renderLayer(indicatorAsset, manifest),
           ),
      ],
    );
  }

  Widget _renderLed(SkinManifest manifest, cfg.BehaviorConfig config) {
    final bool on = state.isOn;
    final assetPath = on 
        ? (config.layers['on'] ?? (config.layers.isNotEmpty ? config.layers.values.first : '')) 
        : (config.layers['off'] ?? (config.layers.isNotEmpty ? config.layers.values.first : ''));
    
    if (assetPath.isEmpty) return const SizedBox.shrink();
    
    final bool isGlowEnabled = config.effects['glow_states']?.contains('on') ?? true;
    final bool drivenByOverride = config.effects['glow_driven_by'] == 'color_override';
    final String? glowAsset = config.effects['glow_asset'];
    
    final Color? tint = drivenByOverride ? state.colorOverride : null;

    return Stack(
      children: [
        _renderLayer(assetPath, manifest, tint: tint),
        if (on && isGlowEnabled && glowAsset != null)
           _renderLayer(glowAsset, manifest, isImage: true, tint: tint, glow: 1.5),
      ],
    );
  }

  Widget _renderToggleSwitch(SkinManifest manifest, cfg.BehaviorConfig config) {
    final bool on = state.isOn;
    final offAsset = config.layers['off'] ?? (config.layers.isNotEmpty ? config.layers.values.first : '');
    final onAsset = config.layers['on'] ?? (config.layers.isNotEmpty ? config.layers.values.last : '');

    if (offAsset.isEmpty || onAsset.isEmpty) return const SizedBox.shrink();
    final bool crossfade = config.effects['crossfade'] ?? true;

    if (!crossfade) {
      return _renderLayer(on ? onAsset : offAsset, manifest);
    }

    return Stack(
      children: [
        Opacity(
          opacity: 1.0 - state.value, // Assumes state.value animates 0->1 for toggle
          child: _renderLayer(offAsset, manifest),
        ),
        Opacity(
          opacity: state.value,
          child: _renderLayer(onAsset, manifest),
        ),
      ],
    );
  }

  // --- Base SVG/Image Renderer ---

  Widget _renderLayer(String relPath, SkinManifest manifest, {Color? tint, double glow = 1.0, bool isImage = false}) {
    final fullPath = 'resources/skins/${manifest.name}/$widgetFolder/$relPath';
    final Color? accent = tint ?? (state.colorOverride ?? manifest.tokens.styles[state.styleIndex]?.primary);

    Widget content;
    if (isImage || relPath.toLowerCase().endsWith('.png') || relPath.toLowerCase().endsWith('.jpg')) {
      content = Image.asset(
        fullPath,
        fit: BoxFit.contain,
        color: tint,
        colorBlendMode: tint != null ? BlendMode.srcIn : null,
      );
    } else {
      content = SvgPicture.asset(
        fullPath,
        fit: BoxFit.contain,
        colorFilter: tint != null ? ColorFilter.mode(tint, BlendMode.srcIn) : null,
      );
    }

    if (glow > 1.0) {
      content = Opacity(
        opacity: (glow - 1.0).clamp(0.0, 1.0),
        child: content,
      );
    }

    return InteractionProxy(
      state: state,
      child: content,
    );
  }
}

class _RelativeClipper extends CustomClipper<Rect> {
  final double value;
  final bool isHorizontal;
  _RelativeClipper({required this.value, required this.isHorizontal});

  @override
  Rect getClip(Size size) {
    if (isHorizontal) {
      return Rect.fromLTWH(0, 0, size.width * value, size.height);
    } else {
      return Rect.fromLTWH(0, size.height * (1.0 - value), size.width, size.height * value);
    }
  }
  @override
  bool shouldReclip(_RelativeClipper old) => old.value != value;
}

class _PositionedAcrossAxis extends StatelessWidget {
  final double value;
  final bool isHorizontal;
  final Widget child;
  const _PositionedAcrossAxis({required this.value, required this.isHorizontal, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // We assume the child (thumb) wants to be centered on the value
      // This is a simplified approach; true precision requires measuring child or knowing its spec size.
      if (isHorizontal) {
        final double pos = constraints.maxWidth * value;
        return Positioned(
          left: pos,
          top: 0, bottom: 0,
          child: FractionalTranslation(translation: const Offset(-0.5, 0), child: child),
        );
      } else {
        final double pos = constraints.maxHeight * (1.0 - value);
        return Positioned(
          top: pos,
          left: 0, right: 0,
          child: FractionalTranslation(translation: const Offset(0, -0.5), child: child),
        );
      }
    });
  }
}

/// Helper to ensure state is available to sub-widgets if needed
class InteractionProxy extends StatelessWidget {
  final RKSkinState state;
  final Widget child;
  const InteractionProxy({super.key, required this.state, required this.child});
  @override
  Widget build(BuildContext context) => child;
}
