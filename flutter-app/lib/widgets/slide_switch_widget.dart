import 'package:flutter/material.dart';
import '../models/widget_config.dart';
import '../models/protocol.dart';
import '../theme/skin/renderers/dynamic_skin_renderer.dart';
import '../theme/skin/renderers/skin_renderer.dart';
import '../theme/skin/skin_manager.dart';
import '../theme/skin/skin_tokens.dart';

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
    final manifest = SkinManager().current;
    final bool isNative = manifest?.renderer == SkinRendererType.native || manifest?.name == 'neon';

    final renderer = DynamicSkinRenderer(
      widgetFolder: 'slide_switch',
      state: RKSkinState(
        isOn: active,
        value: value.toDouble(),
        x: config.x,
        y: config.y,
        styleIndex: config.style,
        label: config.label,
        onText: config.onText,
        offText: config.offText,
        icon: config.icon,
        scale: scale,
        onChanged: (val) {
          onChanged(val > 0.5 ? 1 : 0);
        },
      ),
    );

    if (isNative) return renderer;

    return GestureDetector(
      onTap: () => onChanged(active ? 0 : 1),
      child: renderer,
    );
  }
}
