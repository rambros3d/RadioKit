import 'package:flutter/material.dart';
import '../models/widget_config.dart';
import '../theme/skin/renderers/dynamic_skin_renderer.dart';
import '../theme/skin/renderers/skin_renderer.dart';

/// LED widget — displays an RGB colour set by the device.
/// Fully skinned using v1.6 Mixed-Mode engine.
class LedWidget extends StatelessWidget {
  final WidgetConfig config;

  /// Expected: List<int> [state, r, g, b, opacity] or palette index
  final dynamic value;

  const LedWidget({
    super.key,
    required this.config,
    required this.value,
  });

  bool get _isOn {
    if (value is List<int>) {
      final v = value as List<int>;
      return v.isNotEmpty && v[0] != 0;
    }
    return (value as int) != 0;
  }

  Color get _color {
    if (value is List<int>) {
      final v       = value as List<int>;
      final r       = v.length > 1 ? v[1] : 0;
      final g       = v.length > 2 ? v[2] : 0;
      final b       = v.length > 3 ? v[3] : 0;
      final opacity = v.length > 4 ? v[4] : 255;
      return Color.fromARGB(opacity, r, g, b);
    }
    // Static fallback palette for legacy non-RGB payloads
    switch (value as int) {
      case 1:  return Colors.red;
      case 2:  return Colors.green;
      case 3:  return Colors.blue;
      case 4:  return Colors.yellow;
      default: return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DynamicSkinRenderer(
      widgetFolder: 'led',
      state: RKSkinState(
        isOn: _isOn,
        colorOverride: _color,
        styleIndex: config.style,
      ),
    );
  }
}
