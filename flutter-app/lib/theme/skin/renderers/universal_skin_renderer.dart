import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'skin_renderer.dart';
import '../skin_manager.dart';
import '../skin_tokens.dart';
import '../behavior_config.dart' as cfg;
import 'svg_loader.dart';

/// The unified renderer for all RadioKit skins (SVG, Native, Hybrid).
/// It resolves layers from a widget's config.json and builds a Stack.
class UniversalSkinRenderer extends SkinRenderer {
  const UniversalSkinRenderer({
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

        final layers = _getLayers(config);
        
        return Stack(
          children: layers.map((l) => _buildLayer(context, l, manifest, config)).toList(),
        );
      },
    );
  }

  /// Resolves which layers to render. 
  /// Falls back to legacy 'states' logic if 'renderingLayers' is empty.
  List<cfg.RenderingLayer> _getLayers(cfg.BehaviorConfig config) {
    if (config.renderingLayers.isNotEmpty) {
      if (layer != null) {
        // 1. Try to find specifically by role (recursive)
        final found = _findLayerRecursive(config.renderingLayers, layer!);
        if (found != null) return [found];

        // 2. Fallback: If it's a standard role but missing from config,
        // and we have universal layers, we assume the user wants the whole config
        // to represent that component (common for 'item' in MultipleWidget or 'indicator' in Knob).
        const standardRoles = {'track', 'thumb', 'indicator', 'item'};
        if (standardRoles.contains(layer)) {
          return config.renderingLayers;
        }

        return []; // Hide if explicitly requested a role that doesn't exist
      }
      return config.renderingLayers;
    }

    // --- Legacy / Backward Compatibility Path ---
    final stateKey = _stateKey();
    final assetPath = config.states[stateKey] ?? config.layers[layer ?? stateKey];
    
    if (assetPath != null) {
      return [
        cfg.RenderingLayer(
          type: cfg.LayerType.svg,
          props: {'path': assetPath, 'autoTint': false},
        )
      ];
    }
    return [];
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
    // 1. Check Visibility
    if (!_isVisible(layerSpec.visibility)) return const SizedBox.shrink();

    // 2. Render based on Type
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
    }
  }

  // ─── Layer Renderers ───────────────────────────────────────────────────────

  Widget _renderSvg(Map<String, dynamic> props, SkinManifest manifest) {
    final relPath = _resolveString(props['path'], manifest);
    if (relPath.isEmpty) return const SizedBox.shrink();

    final bool shouldTint = props['autoTint'] ?? false;
    final Color? tintColor = shouldTint ? _getAccentColor(manifest) : null;

    final fullPath = 'resources/skins/${manifest.name}/$widgetFolder/$relPath';

    return SvgPicture.asset(
      fullPath,
      colorFilter: tintColor != null ? ColorFilter.mode(tintColor, BlendMode.srcIn) : null,
      fit: BoxFit.contain,
    );
  }

  Widget _renderNeumorphic(Map<String, dynamic> props, SkinManifest manifest) {
    final double d = _resolveDouble(props['depth'], manifest, 0.8);
    final double intensity = _resolveDouble(props['intensity'], manifest, 0.2);
    final double radius = _resolveDouble(props['borderRadius'], manifest, 1.6);
    final Color bg = _resolveColor(props['color'], manifest, manifest.tokens.colors['surface'] ?? const Color(0xFF111111));
    
    // Pressed state logic
    bool pressed = state.isPressed || state.isOn;
    if (props['isPressed'] != null) {
      pressed = _resolveBool(props['isPressed'], manifest, pressed);
    }

    final Color lightShadow = Colors.white.withOpacity(intensity);
    final Color darkShadow = Colors.black.withOpacity(intensity * 2.5);

    final double margin = _resolveDouble(props['margin'], manifest, 0.0);
    
    final Widget container = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
          boxShadow: pressed ? [] : [
              BoxShadow(
                color: lightShadow,
                offset: Offset(-d, -d),
                blurRadius: d.abs() * 2,
              ),
              BoxShadow(
                color: darkShadow,
                offset: Offset(d, d),
                blurRadius: d.abs() * 2,
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            if (pressed)
              Positioned(
                top: -d.abs(), left: -d.abs(), right: -d.abs(), bottom: -d.abs(),
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

    if (margin > 0) {
      return Padding(
        padding: EdgeInsets.all(margin),
        child: container,
      );
    }
    return container;
  }

  Widget _renderLed(Map<String, dynamic> props, SkinManifest manifest) {
    final active = state.isOn;
    final double size = _resolveDim(props['size'], manifest, 4.0);
    final Color accent = _getAccentColor(manifest);
    final double glow = _resolveDouble(manifest.tokens.effects['glowIntensity'], manifest, 1.0);

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? accent : accent.withOpacity(0.1),
          boxShadow: active ? [
            BoxShadow(
              color: accent.withOpacity((0.6 * glow.abs()).clamp(0.0, 1.0)),
              blurRadius: (15 * glow).abs(),
              spreadRadius: (2 * glow).abs(),
            ),
          ] : null,
        ),
      ),
    );
  }

  Widget _renderBox(Map<String, dynamic> props, SkinManifest manifest) {
    final double width = _resolveDim(props['width'], manifest, 20.0);
    final double height = _resolveDim(props['height'], manifest, 8.0);
    final double radius = _resolveDim(props['borderRadius'], manifest, 1.6);
    final Color color = _resolveColor(props['color'], manifest, Colors.transparent);
    
    Gradient? gradient;
    if (props['gradient'] != null) {
      gradient = _parseGradient(props['gradient'], manifest);
    }

    final List<BoxShadow> outerShadows = [];
    final List<Map<String, dynamic>> innerShadows = [];
    
    if (props['boxShadow'] is List) {
      for (var s in props['boxShadow']) {
        final bool isInset = s['inset'] == true;
        if (isInset) {
          innerShadows.add(s);
        } else {
          outerShadows.add(_parseBoxShadow(s, manifest));
        }
      }
    }

    Widget content = Container(
      width: width.abs(),
      height: height.abs(),
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius.abs()),
        boxShadow: outerShadows,
      ),
    );

    if (innerShadows.isNotEmpty) {
      for (var s in innerShadows) {
        content = _applyInnerShadow(content, s, radius, manifest);
      }
    }

    if (props['margin'] != null) {
      final m = _resolve<double>(props['margin'], manifest, 0.0);
      content = Padding(padding: EdgeInsets.all(m), child: content);
    }

    return Center(child: content);
  }

  Gradient? _parseGradient(Map<String, dynamic> json, SkinManifest manifest) {
    final String type = json['type'] ?? 'linear';
    final List<dynamic> colorsRaw = json['colors'] ?? [];
    final List<Color> colors = colorsRaw.map((c) => _resolveColor(c, manifest, Colors.black)).toList();
    
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
      color: _resolveColor(json['color'], manifest, Colors.black).withOpacity(_resolve<double>(json['opacity'], manifest, 1.0)),
      offset: Offset(
        _resolveDim(json['offsetX'], manifest, 0.0),
        _resolveDim(json['offsetY'], manifest, 0.0),
      ),
      blurRadius: _resolveDim(json['blur'], manifest, 1.0).abs(),
      spreadRadius: _resolveDim(json['spread'], manifest, 0.0),
    );
  }

  Widget _applyInnerShadow(Widget child, Map<String, dynamic> shadow, double radius, SkinManifest manifest) {
    final blur = _resolveDim(shadow['blur'], manifest, 1.0).abs();
    final color = _resolveColor(shadow['color'], manifest, Colors.black).withOpacity(_resolve<double>(shadow['opacity'], manifest, 1.0));
    final offset = Offset(
      _resolveDim(shadow['offsetX'], manifest, 0.0),
      _resolveDim(shadow['offsetY'], manifest, 0.0),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius.abs()),
      child: Stack(
        children: [
          child,
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius.abs()),
                border: Border.all(color: Colors.transparent, width: 0),
                boxShadow: [
                  BoxShadow(
                    color: color,
                    blurRadius: blur,
                    offset: offset,
                    spreadRadius: -blur / 2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderIcon(Map<String, dynamic> props, SkinManifest manifest) {
    final String iconName = _resolve<String>(props['icon'], manifest, state.icon);
    final Color color = _resolveColor(props['color'], manifest, Colors.white);
    final double size = _resolveDim(props['size'], manifest, 4.8);
    
    final List<Shadow> shadows = [];
    if (props['shadows'] is List) {
      for (var s in props['shadows']) {
        shadows.add(_parseShadow(s, manifest));
      }
    } else {
       final bool isGlowing = state.isPressed || state.isOn;
       if (isGlowing) shadows.add(Shadow(color: color.withOpacity(0.8), blurRadius: 10));
    }

    return Center(
      child: Icon(
        _getIconData(iconName),
        color: color,
        size: size,
        shadows: shadows.isNotEmpty ? shadows : null,
      ),
    );
  }

  Widget _renderText(Map<String, dynamic> props, SkinManifest manifest) {
    final String text = _resolve<String>(props['text'], manifest, state.label);
    final Color color = _resolveColor(props['color'], manifest, Colors.white);
    final double size = _resolveDim(props['size'], manifest, 2.4);
    final String? family = manifest.tokens.typography['fontFamily'];

    final List<Shadow> shadows = [];
    if (props['shadows'] is List) {
      for (var s in props['shadows']) {
        shadows.add(_parseShadow(s, manifest));
      }
    }

    return Center(
      child: Text(
        text,
        style: _getStyle(family, color, state.isOn).copyWith(
          fontSize: size,
          shadows: shadows.isNotEmpty ? shadows : null,
        ),
      ),
    );
  }

  Shadow _parseShadow(Map<String, dynamic> json, SkinManifest manifest) {
    return Shadow(
      color: _resolveColor(json['color'], manifest, Colors.black).withOpacity(_resolve<double>(json['opacity'], manifest, 1.0)),
      offset: Offset(
        _resolveDim(json['offsetX'], manifest, 0.0),
        _resolveDim(json['offsetY'], manifest, 0.0),
      ),
      blurRadius: _resolveDim(json['blur'], manifest, 1.0).abs(),
    );
  }

  Widget _renderSwitch(cfg.RenderingLayer spec, SkinManifest manifest, cfg.BehaviorConfig config) {
    final props = spec.props;
    final active = state.isOn;
    final String animMode = props['animation'] ?? 'squishy';
    
    final trackLayer = spec.children?.firstWhere((l) => l.props['role'] == 'track', orElse: () => cfg.RenderingLayer(type: cfg.LayerType.box, props: {'width': 12.0, 'height': 6.0, 'borderRadius': 20.0, 'color': '#surface'}));
    final thumbLayer = spec.children?.firstWhere((l) => l.props['role'] == 'thumb', orElse: () => cfg.RenderingLayer(type: cfg.LayerType.box, props: {'width': 5.2, 'height': 5.2, 'borderRadius': 20.0, 'color': '#accent'}));

    final trackWidth = _resolveDim(trackLayer?.props['width'], manifest, 60.0);
    final thumbWidth = _resolveDim(thumbLayer?.props['width'], manifest, 26.0);

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      curve: const Cubic(0.5, 0.5, 0.3, 1.2),
      tween: Tween<double>(end: active ? 1.0 : 0.0),
      builder: (context, value, child) {
        final double stretch = animMode == 'squishy' ? (0.5 - (value - 0.5).abs()) * 0.4 : 0.0;
        
        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            if (trackLayer != null) _buildLayer(context, trackLayer, manifest, config),
            if (thumbLayer != null)
            Positioned(
              left: value * (trackWidth - thumbWidth - 4.0) + 2.0, 
              child: Transform.scale(
                scaleX: 1.0 + stretch,
                scaleY: 1.0 - stretch * 0.5,
                child: _buildLayer(context, thumbLayer, manifest, config),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _renderSlider(cfg.RenderingLayer spec, SkinManifest manifest, cfg.BehaviorConfig config) {
    final thumbLayer = spec.children?.firstWhere((l) => l.props['role'] == 'thumb', orElse: () => cfg.RenderingLayer(type: cfg.LayerType.box, props: {'width': 6.0, 'height': 6.0, 'borderRadius': 20.0, 'color': '#accent'}));
    final otherLayers = spec.children?.where((l) => l.props['role'] != 'thumb').toList() ?? [];

    return LayoutBuilder(
      builder: (context, constraints) {
        final double value = state.value;
        final thumbSize = thumbLayer != null ? _resolveDim(thumbLayer.props['width'], manifest, 6.0) : 6.0 * state.scale;

        return Center(
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                 ...otherLayers.map((l) => _buildLayer(context, l, manifest, config)),
                 if (thumbLayer != null)
                 Positioned(
                   left: value * (constraints.maxWidth - thumbSize),
                   child: _buildLayer(context, thumbLayer, manifest, config),
                 )
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _renderAlignment(BuildContext context, Map<String, dynamic> props, SkinManifest manifest, cfg.BehaviorConfig config) {
    final String? alignStr = props['align'] as String?;
    final alignment = _parseAlignment(alignStr);
    final childLayerJson = props['child'] as Map<String, dynamic>?;
    if (childLayerJson == null) return const SizedBox.shrink();

    final childLayer = cfg.RenderingLayer.fromJson(childLayerJson);

    return Align(
      alignment: alignment,
      child: _buildLayer(context, childLayer, manifest, config),
    );
  }

  // ─── Token Resolution ──────────────────────────────────────────────────────

  T _resolve<T>(dynamic val, SkinManifest manifest, T fallback, {bool isDimension = false}) {
    if (val == null) return fallback;
    if (val is! String) {
      if (T == double && val is num) {
        final d = val.toDouble();
        return (isDimension ? d * state.scale : d) as T;
      }
      if (val is T) return val;
      return fallback;
    }

    final String s = val.trim();
    
    if (s.startsWith('$state.') && s.contains('?') && s.contains(':')) {
      final parts = s.split('?');
      final condition = parts[0].trim();
      final options = parts[1].split(':');
      if (options.length == 2) {
        final trueVal = options[0].trim();
        final falseVal = options[1].trim();

        bool result = false;
        if (condition == '$state.isPressed') result = state.isPressed;
        else if (condition == '$state.isOn') result = state.isOn;

        return _resolve(result ? trueVal : falseVal, manifest, fallback, isDimension: isDimension);
      }
    }

    if (s.startsWith('#')) {
      if (s == '#accent') {
        final color = _getAccentColor(manifest);
        if (T == Color) return color as T;
      }
      final tokenKey = s.substring(1);
      final tokenValue = manifest.tokens.colors[tokenKey];
      if (tokenValue != null) {
        if (T == Color) return tokenValue as T;
      }
    }

    // Handle Effect/Shape Tokens: "@glowIntensity" or "@borderRadius"
    if (s.startsWith('@')) {
      final tokenKey = s.substring(1);
      final dynamic tokenValue = manifest.tokens.effects[tokenKey] ?? manifest.tokens.shapes[tokenKey];
      if (tokenValue != null) {
        if (T == double && tokenValue is num) {
          final d = tokenValue.toDouble();
          return (isDimension ? d * state.scale : d) as T;
        }
        if (tokenValue is T) return tokenValue;
      }
    }

    if (s == '$state.label') {
      if (T == String) return state.label as T;
    }

    if (T == Color) {
      return _parseColor(s) as T;
    }
    if (T == double) {
      final d = double.tryParse(s) ?? (fallback is double ? fallback : 0.0);
      return (isDimension ? d * state.scale : d) as T;
    }
    if (T == Alignment) {
       return _parseAlignment(s) as T;
    }
    if (T == String) {
      return s as T;
    }
    return fallback;
  }

  Color _resolveColor(dynamic val, SkinManifest manifest, Color fallback) {
    return _resolve<Color>(val, manifest, fallback);
  }

  String _resolveString(dynamic val, SkinManifest manifest) {
    return _resolve<String>(val, manifest, '');
  }

  double _resolveDouble(dynamic val, SkinManifest manifest, double fallback) {
    return _resolve<double>(val, manifest, fallback);
  }

  double _resolveDim(dynamic val, SkinManifest manifest, double fallback) {
    return _resolve<double>(val, manifest, fallback, isDimension: true);
  }

  bool _resolveBool(dynamic val, SkinManifest manifest, bool fallback) {
    if (val == '$state.isPressed') return state.isPressed;
    if (val == '$state.isOn') return state.isOn;
    if (val is bool) return val;
    return fallback;
  }

  Color _getAccentColor(SkinManifest manifest) {
    final style = manifest.tokens.styles[state.styleIndex] ?? manifest.tokens.styles.values.first;
    return state.colorOverride ?? style.primary;
  }

  bool _isVisible(Map<String, dynamic>? vis) {
    if (vis == null) return true;
    if (vis.containsKey('layer')) {
      if (layer != null && layer != vis['layer']) return false;
    }
    if (vis.containsKey('state')) {
      final target = vis['state'];
      return _stateKey() == target;
    }
    if (vis.containsKey('on')) return state.isOn == vis['on'];
    if (vis.containsKey('pressed')) return state.isPressed == vis['pressed'];
    return true;
  }

  String _stateKey() {
    switch (widgetFolder) {
      case 'button_push': return state.isPressed ? 'pressed' : 'idle';
      case 'button_toggle': return state.isOn ? 'on' : 'off';
      case 'switch': return state.isOn ? 'on' : 'off';
      case 'display': return 'background';
      case 'led': return state.isOn ? 'on' : 'base';
      case 'multiple_button':
      case 'multiple_select': return state.isOn ? 'active' : 'idle';
      default: return state.isPressed ? 'pressed' : 'idle';
    }
  }

  Alignment _parseAlignment(String? align) {
    switch (align) {
      case 'topLeft': return Alignment.topLeft;
      case 'topRight': return Alignment.topRight;
      case 'bottomLeft': return Alignment.bottomLeft;
      case 'bottomRight': return Alignment.bottomRight;
      case 'centerLeft': return Alignment.centerLeft;
      case 'centerRight': return Alignment.centerRight;
      case 'topCenter': return Alignment.topCenter;
      case 'bottomCenter': return Alignment.bottomCenter;
      default: return Alignment.center;
    }
  }

  Color _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return Colors.transparent;
    if (colorStr.startsWith('#')) {
      final hex = colorStr.replaceFirst('#', '').replaceAll(' ', '');
      try {
        if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
        if (hex.length == 8) return Color(int.parse(hex, radix: 16));
      } catch (_) {
        return Colors.transparent;
      }
    }
    return Colors.transparent;
  }

  TextStyle _getStyle(String? family, Color color, bool bold) {
    try {
      return GoogleFonts.getFont(
        family ?? 'Inter',
        color: color,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      );
    } catch (_) {
      return TextStyle(color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal);
    }
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'power': return Icons.power_settings_new;
      case 'settings': return Icons.settings;
      case 'wifi': return Icons.wifi;
      case 'bluetooth': return Icons.bluetooth;
      case 'play_arrow': return Icons.play_arrow;
      case 'pause': return Icons.pause;
      case 'skip_next': return Icons.skip_next;
      case 'skip_previous': return Icons.skip_previous;
      default: return Icons.radio_button_checked;
    }
  }
}
