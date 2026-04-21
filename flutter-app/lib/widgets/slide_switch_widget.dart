import 'package:flutter/material.dart';
import '../models/widget_config.dart';
import '../models/protocol.dart';
import '../theme/skin/renderers/dynamic_skin_renderer.dart';
import '../theme/skin/renderers/skin_renderer.dart';

/// Skinned Slide Switch widget.
/// Resolves to 'switch' folder in the skin pack.
class SlideSwitchWidget extends StatelessWidget {
  final WidgetConfig config;
  final int value;
  final ValueChanged<int> onChanged;
  final double scale;

  const SlideSwitchWidget({
    super.key,
    required this.config,
    required this.value,
    required this.onChanged,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final active = value != 0;

    return GestureDetector(
      onTap: () => onChanged(active ? 0 : 1),
      child: DynamicSkinRenderer(
        widgetFolder: 'toggle_switch',
        state: RKSkinState(
          isOn: active,
          styleIndex: config.style,
          label: config.label,
          icon: config.icon,
          scale: scale,
        ),
      ),
    );
  }
}
