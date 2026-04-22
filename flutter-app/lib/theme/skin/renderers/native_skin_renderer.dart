import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'skin_renderer.dart';
import '../skin_manager.dart';
import '../skin_tokens.dart';
import '../behavior_config.dart' as cfg;
import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter_oknob/flutter_oldschool_knob.dart';
import 'svg_loader.dart';
import '../../../utils/icon_utils.dart';

/// Renderer for Native/Primitive skins (e.g. Neon).
/// Uses 'renderingLayers' from config.json to build the UI from Box, Icon, Text primitives.
class NativeSkinRenderer extends SkinRenderer {
  const NativeSkinRenderer({
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

        if (manifest.name == 'neon' || manifest.renderer == SkinRendererType.native) {
          if (widgetFolder == 'multiple_button' && layer == 'base') {
            return _renderMultipleButtonRolling(context, manifest, config);
          }
          if (widgetFolder == 'slide_switch' && layer == null) {
            // Force render the switch even if config is empty (fail-safe)
            return _renderSwitch(cfg.RenderingLayer(type: cfg.LayerType.switch_layer, props: {}), manifest, config);
          }
        }

        final layers = _getLayers(config);
        
        return Stack(
          children: layers.map((l) => _buildLayer(context, l, manifest, config)).toList(),
        );
      },
    );
  }

  List<cfg.RenderingLayer> _getLayers(cfg.BehaviorConfig config) {
    if (layer != null) {
      final found = _findLayerRecursive(config.renderingLayers, layer!);
      if (found != null) return [found];
      
      const standardRoles = {'track', 'thumb', 'indicator', 'item'};
      if (standardRoles.contains(layer)) {
        return config.renderingLayers;
      }
      return [];
    }
    return config.renderingLayers;
  }

  cfg.RenderingLayer? _findLayerRecursive(List<cfg.RenderingLayer> layers, String role) {
    for (final l in layers) {
      if (l.props['role'] == role) return l;
      if (l.children != null) {
        final found = _findLayerRecursive(l.children!, role);
        if (found != null) return found;
      }
    }
    return null;
  }

  Widget _buildLayer(BuildContext context, cfg.RenderingLayer layerSpec, SkinManifest manifest, cfg.BehaviorConfig config) {
    if (!_isVisible(layerSpec.visibility)) return const SizedBox.shrink();

    switch (layerSpec.type) {
      case cfg.LayerType.svg:
        return _renderSvg(layerSpec.props, manifest);
      case cfg.LayerType.neumorphic:
        return _renderNeumorphic(layerSpec.props, manifest);
      case cfg.LayerType.led:
        return _renderLed(layerSpec.props, manifest);
      case cfg.LayerType.icon:
        return _renderIcon(layerSpec.props, manifest);
      case cfg.LayerType.text:
        return _renderText(layerSpec.props, manifest);
      case cfg.LayerType.alignment:
        return _renderAlignment(context, layerSpec.props, manifest, config);
      case cfg.LayerType.box:
        return _renderBox(layerSpec.props, manifest);
      case cfg.LayerType.switch_layer:
        return _renderSwitch(layerSpec, manifest, config);
      case cfg.LayerType.slider:
        return _renderSlider(layerSpec, manifest, config);
      case cfg.LayerType.repeater:
        return _renderRepeater(context, layerSpec.props, manifest, config);
      case cfg.LayerType.joystick:
        return _renderJoystickNative(context, layerSpec.props, manifest, config);
      case cfg.LayerType.knob:
        return _renderKnobNative(context, layerSpec.props, manifest, config);
    }
  }

  // --- Primitives ---

  Widget _renderSvg(Map<String, dynamic> props, SkinManifest manifest) {
    final relPath = _resolveString(props['path'], manifest);
    if (relPath.isEmpty) return const SizedBox.shrink();

    final bool shouldTint = props['autoTint'] ?? false;
    final Color? tintColor = shouldTint ? _getAccentColor(manifest) : null;
    final fullPath = 'resources/skins/${manifest.name}/$widgetFolder/$relPath';

    return Center(
      widthFactor: 1.0,
      heightFactor: 1.0,
      child: SvgPicture.asset(
        fullPath,
        colorFilter: tintColor != null ? ColorFilter.mode(tintColor, BlendMode.srcIn) : null,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _renderNeumorphic(Map<String, dynamic> props, SkinManifest manifest) {
    final double d = _resolveDouble(props['depth'], manifest, 0.8);
    final double intensity = _resolveDouble(props['intensity'], manifest, 0.2);
    final double radius = _resolveDouble(props['borderRadius'], manifest, 1.6);
    final Color bg = _resolveColor(props['color'], manifest, manifest.tokens.colors['surface'] ?? const Color(0xFF111111));
    bool pressed = state.isPressed || state.isOn;
    if (props['isPressed'] != null) pressed = _resolveBool(props['isPressed'], manifest, pressed);

    final Color lightShadow = Colors.white.withValues(alpha: intensity);
    final Color darkShadow = Colors.black.withValues(alpha: intensity * 2.5);
    final double margin = _resolveDouble(props['margin'], manifest, 0.0);
    
    final Widget container = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: pressed ? [] : [
          BoxShadow(color: lightShadow, offset: Offset(-d, -d), blurRadius: d.abs() * 2),
          BoxShadow(color: darkShadow, offset: Offset(d, d), blurRadius: d.abs() * 2),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            if (pressed)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(color: darkShadow, width: d.abs() / 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return margin > 0 ? Padding(padding: EdgeInsets.all(margin), child: container) : container;
  }

  Widget _renderLed(Map<String, dynamic> props, SkinManifest manifest) {
    final active = state.isOn;
    final double size = _resolveDim(props['size'], manifest, 4.0);
    final Color accent = _getAccentColor(manifest);
    final double glow = _resolveDouble(manifest.tokens.effects['glowIntensity'], manifest, 1.0);

    return Center(
      widthFactor: 1.0,
      heightFactor: 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? accent : accent.withValues(alpha: 0.1),
          boxShadow: active ? [
            BoxShadow(
              color: accent.withValues(alpha: (0.6 * glow.abs()).clamp(0.0, 1.0)),
              blurRadius: (15 * glow).abs(),
              spreadRadius: (2 * glow).abs(),
            ),
          ] : null,
        ),
      ),
    );
  }

  Widget _renderBox(Map<String, dynamic> props, SkinManifest manifest) {
    final double width = _resolveDim(props['width'], manifest, 8.0);
    final double height = _resolveDim(props['height'], manifest, 8.0);
    final double radius = _resolveDim(props['borderRadius'], manifest, 1.0);
    final Color color = _resolveColor(props['color'], manifest, Colors.transparent);
    
    Gradient? gradient;
    if (props['gradient'] != null) gradient = _parseGradient(props['gradient'], manifest);

    final List<BoxShadow> outerShadows = [];
    final List<Map<String, dynamic>> innerShadows = [];
    if (props['boxShadow'] is List) {
      for (var s in props['boxShadow']) {
        if (s['inset'] == true) innerShadows.add(s);
        else outerShadows.add(_parseBoxShadow(s, manifest));
      }
    }

    Widget content = Container(
      width: width.abs(), height: height.abs(),
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius.abs()),
        boxShadow: outerShadows,
      ),
    );

    for (var s in innerShadows) {
      content = _applyInnerShadow(content, s, radius, manifest);
    }

    if (props['margin'] != null) {
      content = Padding(padding: EdgeInsets.all(_resolve<double>(props['margin']!, manifest, 0.0)), child: content);
    }

    final double offX = _resolveDim(props['offsetX'], manifest, 0.0);
    final double offY = _resolveDim(props['offsetY'], manifest, 0.0);
    if (offX != 0 || offY != 0) {
      content = Transform.translate(offset: Offset(offX, offY), child: content);
    }

    return Center(widthFactor: 1.0, heightFactor: 1.0, child: content);
  }

  Gradient? _parseGradient(Map<String, dynamic> json, SkinManifest manifest) {
    final String type = json['type'] ?? 'linear';
    final List<Color> colors = (json['colors'] as List).map((c) => _resolveColor(c, manifest, Colors.black)).toList();
    if (colors.isEmpty) return null;

    if (type == 'radial') {
      return RadialGradient(
        colors: colors,
        center: _resolve<Alignment>(json['center'], manifest, Alignment.center),
        radius: _resolve<double>(json['radius'], manifest, 0.5),
      );
    } else {
      return LinearGradient(
        colors: colors,
        begin: _resolve<Alignment>(json['begin'], manifest, Alignment.topCenter),
        end: _resolve<Alignment>(json['end'], manifest, Alignment.bottomCenter),
      );
    }
  }

  BoxShadow _parseBoxShadow(Map<String, dynamic> json, SkinManifest manifest) {
    return BoxShadow(
      color: _resolveColor(json['color'], manifest, Colors.black).withValues(alpha: _resolve<double>(json['opacity'], manifest, 1.0)),
      offset: Offset(_resolveDim(json['offsetX'], manifest, 0.0), _resolveDim(json['offsetY'], manifest, 0.0)),
      blurRadius: _resolveDim(json['blur'], manifest, 1.0).abs(),
      spreadRadius: _resolveDim(json['spread'], manifest, 0.0),
    );
  }

  Widget _applyInnerShadow(Widget child, Map<String, dynamic> shadow, double radius, SkinManifest manifest) {
    final blur = _resolveDim(shadow['blur'], manifest, 1.0).abs();
    final color = _resolveColor(shadow['color'], manifest, Colors.black).withValues(alpha: _resolve<double>(shadow['opacity'], manifest, 1.0));
    final offset = Offset(_resolveDim(shadow['offsetX'], manifest, 0.0), _resolveDim(shadow['offsetY'], manifest, 0.0));

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius.abs()),
      child: Stack(
        children: [
          child,
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius.abs()),
                boxShadow: [
                  BoxShadow(color: color, blurRadius: blur, offset: offset, spreadRadius: _resolveDim(shadow['spread'], manifest, -blur / 2.0)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderIcon(Map<String, dynamic> props, SkinManifest manifest) {
    final String iconName = _resolve<String>(props['icon'] ?? state.icon, manifest, state.icon);
    final Color color = _resolveColor(props['color'], manifest, Colors.white);
    final double size = _resolveDim(props['size'], manifest, 4.8);
    return Center(widthFactor: 1.0, heightFactor: 1.0, child: Icon(_getIconData(iconName), color: color, size: size));
  }

  Widget _renderText(Map<String, dynamic> props, SkinManifest manifest) {
    final String text = _resolve<String>(props['text'] ?? state.label, manifest, state.label);
    final Color color = _resolveColor(props['color'], manifest, Colors.white);
    final double size = _resolveDim(props['size'], manifest, 2.4);
    return Center(widthFactor: 1.0, heightFactor: 1.0, child: Text(text, style: GoogleFonts.getFont(manifest.tokens.typography['fontFamily'] ?? 'Inter', color: color, fontSize: size, fontWeight: state.isOn ? FontWeight.bold : FontWeight.normal)));
  }

  Widget _renderSwitch(cfg.RenderingLayer spec, SkinManifest manifest, cfg.BehaviorConfig config) {
    final active = state.isOn;
    final trackLayer = spec.children?.where((l) => l.props['role'] == 'track').firstOrNull;
    final thumbLayer = spec.children?.where((l) => l.props['role'] == 'thumb').firstOrNull;
    
    // Resolve dimensions from layers if available, else defaults
    // Forced dimensions for a premium feel
    final trackHeight = 15.0 * state.scale; // Matches MultipleButton height baseline
    final trackWidth = trackHeight * 2.5;  // Matches the new kWidgetSlideSwitch aspect ratio (2.5)
    final thumbSize = trackHeight; 
    final radius = trackHeight / 2;

    if (manifest.name == 'neon' || manifest.renderer == SkinRendererType.native) {
      final Color activeColor = _resolveColor('#toggleActive', manifest, _getAccentColor(manifest));
      final Color trackColor = _resolveColor('#toggleTrack', manifest, Colors.grey.shade800);
      
      return Center(
        child: SizedBox(
          width: trackWidth,
          height: trackHeight,
          child: AnimatedToggleSwitch<bool>.dual(
            current: active,
            first: false,
            second: true,
            onChanged: (b) {
              state.onChanged?.call(b ? 1.0 : 0.0);
            },
            animationDuration: const Duration(milliseconds: 300),
            animationCurve: Curves.easeOutBack,
            indicatorSize: Size.square(thumbSize),
            height: trackHeight,
            borderWidth: 1.0 * state.scale,
            style: ToggleStyle(
              backgroundColor: trackColor,
              indicatorColor: Colors.white,
              borderColor: Colors.white10,
              borderRadius: BorderRadius.circular(radius),
              indicatorBorderRadius: BorderRadius.circular(100.0 * state.scale),
            ),
            styleBuilder: (b) => ToggleStyle(
              indicatorColor: b ? activeColor : Colors.white,
              backgroundColor: b ? activeColor.withValues(alpha: 0.3) : trackColor,
            ),
            iconBuilder: (b) => Icon(
              b ? Icons.chevron_right : _getIconData(state.icon.isNotEmpty ? state.icon : 'power'),
              size: thumbSize * 0.6,
              color: b ? Colors.black : Colors.black87,
            ),
            textBuilder: (b) => Center(
              child: Text(
                b ? (state.label.isNotEmpty ? state.label : 'ON') : 'OFF',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: GoogleFonts.getFont(
                  manifest.tokens.typography['fontFamily'] ?? 'Inter',
                  color: Colors.white,
                  fontSize: trackHeight * 0.35,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final defaultTrack = cfg.RenderingLayer(
      type: cfg.LayerType.box,
      props: {'width': trackWidth, 'height': trackHeight, 'color': '#outline', 'borderRadius': trackHeight / 2}
    );
    final defaultThumb = cfg.RenderingLayer(
      type: cfg.LayerType.box,
      props: {'width': thumbSize, 'height': thumbSize, 'color': '#primary', 'borderRadius': thumbSize / 2}
    );

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      tween: Tween<double>(end: active ? 1.0 : 0.0),
      builder: (context, value, child) {
        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            _buildLayer(context, trackLayer ?? defaultTrack, manifest, config),
            Positioned(
              left: value * (trackWidth - thumbSize - 0.5 * state.scale) + 0.25 * state.scale,
              child: _buildLayer(context, thumbLayer ?? defaultThumb, manifest, config),
            ),
          ],
        );
      },
    );
  }

  Widget _renderSlider(cfg.RenderingLayer spec, SkinManifest manifest, cfg.BehaviorConfig config) {
    final thumbLayer = spec.children?.firstWhere((l) => l.props['role'] == 'thumb');
    final otherLayers = spec.children?.where((l) => l.props['role'] != 'thumb').toList() ?? [];

    return LayoutBuilder(builder: (context, constraints) {
      final thumbSize = _resolveDim(thumbLayer?.props['width'], manifest, 4.0);
      return Stack(
        alignment: Alignment.centerLeft,
        children: [
          ...otherLayers.map((l) => _buildLayer(context, l, manifest, config)),
          if (thumbLayer != null)
            Positioned(
              left: state.value * (constraints.maxWidth - thumbSize),
              child: _buildLayer(context, thumbLayer, manifest, config),
            )
        ],
      );
    });
  }

  Widget _renderJoystickNative(BuildContext context, Map<String, dynamic> props, SkinManifest manifest, cfg.BehaviorConfig config) {
    final baseLayerJson = props['base'];
    final stickLayerJson = props['stick'];

    final baseLayer = baseLayerJson != null ? cfg.RenderingLayer.fromJson(baseLayerJson) : null;
    final stickLayer = stickLayerJson != null ? cfg.RenderingLayer.fromJson(stickLayerJson) : null;

    final double size = _resolveDim(props['size'], manifest, 20.0);

    return SizedBox(
      width: size,
      height: size,
      child: Joystick(
        key: const ValueKey('native_joystick'),
        listener: (details) {
          // Send joystick data to device provider
          state.onJoystickChanged?.call(details.x, details.y);
        },
        // Remove IgnorePointer to ensure stick receives hits for the library's GestureDetector
        // Wrap base in a regular expanding Center to prevent it from moving with the Stack alignment
        base: baseLayer != null ? Center(child: _buildLayer(context, baseLayer, manifest, config)) : null,
        stick: stickLayer != null ? _buildLayer(context, stickLayer, manifest, config) : const JoystickStick(),
      ),
    );
  }

  Widget _renderKnobNative(BuildContext context, Map<String, dynamic> props, SkinManifest manifest, cfg.BehaviorConfig config) {
    final double size = _resolveDim(props['size'], manifest, 20.0);
    final Color activeColor = _resolveColor('#primary', manifest, _getAccentColor(manifest));
    final Color surfaceColor = _resolveColor('#surface', manifest, const Color(0xFF111111));
    
    // Scale 0..1 to 0..100
    final double initialValue = state.value * 100;

    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: ClipRect( // Prevent value labels from overflowing the knob's bounding box
          child: OverflowBox(
            maxHeight: size + 40, // Allow some room for labels if they bleed out, but clip them
            maxWidth: size + 40,
            child: FlutterOKnob(
              size: size,
              knobvalue: initialValue,
              minValue: 0,
              maxValue: 100,
              onChanged: (val) {
                // Scale back 0..100 to 0..1
                state.onChanged?.call(val / 100.0);
              },
              markerColor: activeColor,
              innerKnobGradient: LinearGradient(
                colors: [surfaceColor.withValues(alpha: 0.8), surfaceColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              outerRingGradient: LinearGradient(
                colors: [surfaceColor, surfaceColor.withValues(alpha: 0.5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              showKnobLabels: false,
              maxRotationAngle: 270,
              angleOffset: 135,
            ),
          ),
        ),
      ),
    );
  }

  Widget _renderAlignment(BuildContext context, Map<String, dynamic> props, SkinManifest manifest, cfg.BehaviorConfig config) {
    final childLayerJson = props['child'] as Map<String, dynamic>?;
    if (childLayerJson == null) return const SizedBox.shrink();
    return Align(
      alignment: _parseAlignment(props['align']),
      child: _buildLayer(context, cfg.RenderingLayer.fromJson(childLayerJson), manifest, config),
    );
  }

  Widget _renderRepeater(BuildContext context, Map<String, dynamic> props, SkinManifest manifest, cfg.BehaviorConfig config) {
    final int count = props['count'] ?? 1;
    final double radius = _resolveDim(props['radius'], manifest, 15.0);
    final double startAngle = _resolveDouble(props['startAngle'], manifest, 0.0);
    final childLayerJson = props['child'] as Map<String, dynamic>?;
    if (childLayerJson == null || count <= 0) return const SizedBox.shrink();
    final childLayer = cfg.RenderingLayer.fromJson(childLayerJson);

    return Stack(
      alignment: Alignment.center,
      children: List.generate(count, (i) {
        final rad = (startAngle + (i * 360 / count)) * math.pi / 180;
        return Transform.translate(
          offset: Offset(radius * math.sin(rad), -radius * math.cos(rad)),
          child: _buildLayer(context, childLayer, manifest, config),
        );
      }),
    );
  }

  // --- Helpers ---

  T _resolve<T>(dynamic val, SkinManifest manifest, T fallback, {bool isDimension = false}) {
    if (val == null) {
      if (isDimension && fallback is num) return (fallback.toDouble() * state.scale) as T;
      return fallback;
    }
    if (val is! String) {
      if (T == double && val is num) return (isDimension ? val.toDouble() * state.scale : val.toDouble()) as T;
      return val is T ? val : fallback;
    }
    final s = val.trim();

    // Ternary Support: "$state.isOn ? red : blue"
    if (s.contains('?') && s.contains(':')) {
      final parts = s.split('?');
      final conditionStr = parts[0].trim();
      final options = parts[1].split(':');
      
      bool condition = false;
      if (conditionStr == '$state.isOn' || conditionStr == '$state.on') {
        condition = state.isOn;
      } else if (conditionStr == '$state.isPressed' || conditionStr == '$state.pressed') {
        condition = state.isPressed;
      }

      final res = condition ? options[0].trim() : options[1].trim();
      return _resolve<T>(res, manifest, fallback, isDimension: isDimension);
    }
    
    // State Interpolation
    if (s.startsWith('$state.')) {
      final key = s.substring(7);
      if (key == 'label') return (state.label ?? fallback) as T;
      if (key == 'icon') return (state.icon ?? fallback) as T;
      if (key == 'value') return (state.value.toString()) as T;
    }

    if (s.startsWith('#')) {
      final token = s.substring(1);
      if (token == 'accent') return _getAccentColor(manifest) as T;
      final tokenColor = manifest.tokens.colors[token];
      if (tokenColor != null) return tokenColor as T;
      // If token lookup fails, try to parse it as hex if it looks like one, else return fallback
      if (s.length == 4 || s.length == 7 || s.length == 9) {
        return _parseColor(s) as T;
      }
      return fallback as T;
    }
    if (s.startsWith('@')) return (manifest.tokens.effects[s.substring(1)] ?? manifest.tokens.shapes[s.substring(1)] ?? fallback) as T;
    if (T == double) {
      final d = double.tryParse(s) ?? 0.0;
      return (isDimension ? d * state.scale : d) as T;
    }
    if (T == Alignment) return _parseAlignment(s) as T;
    return s as T;
  }

  Color _resolveColor(dynamic val, SkinManifest manifest, Color fallback) => _resolve<Color>(val, manifest, fallback);
  String _resolveString(dynamic val, SkinManifest manifest) => _resolve<String>(val, manifest, '');
  double _resolveDouble(dynamic val, SkinManifest manifest, double fallback) => _resolve<double>(val, manifest, fallback);
  double _resolveDim(dynamic val, SkinManifest manifest, double fallback) => _resolve<double>(val, manifest, fallback, isDimension: true);
  bool _resolveBool(dynamic val, SkinManifest manifest, bool fallback) => val is bool ? val : fallback;

  Color _getAccentColor(SkinManifest manifest) {
    final style = manifest.tokens.styles[state.styleIndex] ?? manifest.tokens.styles.values.first;
    return state.colorOverride ?? style.primary;
  }

  bool _isVisible(Map<String, dynamic>? vis) {
    if (vis == null) return true;
    if (vis['layer'] != null && layer != vis['layer']) return false;
    if (vis['on'] != null && state.isOn != vis['on']) return false;
    if (vis['pressed'] != null && state.isPressed != vis['pressed']) return false;
    return true;
  }

  Alignment _parseAlignment(String? align) {
    switch (align) {
      case 'topLeft': return Alignment.topLeft;
      case 'topRight': return Alignment.topRight;
      case 'centerLeft': return Alignment.centerLeft;
      case 'centerRight': return Alignment.centerRight;
      case 'topCenter': return Alignment.topCenter;
      case 'bottomCenter': return Alignment.bottomCenter;
      default: return Alignment.center;
    }
  }

  Color _parseColor(String? hex) {
    if (hex == null || !hex.startsWith('#')) return Colors.transparent;
    try {
      final h = hex.replaceFirst('#', '');
      // If it's a token name (like #toggleTrack) that failed lookup, it won't be valid hex
      if (h.length != 3 && h.length != 6 && h.length != 8) return Colors.transparent;
      return Color(int.parse(h.length == 6 ? 'FF$h' : (h.length == 3 ? 'FF${h[0]}${h[0]}${h[1]}${h[1]}${h[2]}${h[2]}' : h), radix: 16));
    } catch (_) {
      return Colors.transparent;
    }
  }

  Widget _renderMultipleButtonRolling(BuildContext context, SkinManifest manifest, cfg.BehaviorConfig config) {
    final items = state.items;
    if (items.isEmpty) return const SizedBox.shrink();

    final Color activeColor = _resolveColor('#toggleActive', manifest, _getAccentColor(manifest));
    final Color trackColor = _resolveColor('#toggleTrack', manifest, Colors.grey.shade800);
    
    // Calculate dimensions
    final double h = _resolveDim(10.0, manifest, 10.0);
    final double w = h * items.length;
    final double thumbSize = h * 0.9;

    return Center(
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(h / 2),
          border: Border.all(color: Colors.white10, width: 0.5 * state.scale),
        ),
        child: AnimatedToggleSwitch<int>.rolling(
          current: state.value.toInt().clamp(0, items.length - 1),
          values: List.generate(items.length, (i) => i),
          onChanged: (val) {
            state.onChanged?.call(val.toDouble());
          },
          animationDuration: const Duration(milliseconds: 350),
          animationCurve: Curves.easeOutBack,
          indicatorSize: Size.square(thumbSize),
          height: h,
          style: ToggleStyle(
            indicatorColor: activeColor,
            backgroundColor: Colors.transparent,
          ),
          borderWidth: 0.0,
          iconBuilder: (value, foreground) {
            final item = items[value];
            
            if (item.icon.isNotEmpty) {
              return Icon(
                _getIconData(item.icon),
                size: thumbSize * 0.6,
                color: foreground ? Colors.black : Colors.white70,
              );
            }
            
            return Text(
              _resolveString(item.label, manifest),
              style: GoogleFonts.getFont(
                manifest.tokens.typography['fontFamily'] ?? 'VT323',
                fontSize: h * 0.35,
                color: foreground ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
      ),
    );
  }

  IconData _getIconData(String name) {
    return parseIconFromName(name) ?? Icons.radio_button_checked;
  }
}
