import 'package:flutter/material.dart';
import '../models/widget_config.dart';
import '../theme/skin/renderers/dynamic_skin_renderer.dart';
import '../theme/skin/renderers/skin_renderer.dart';

/// Multiple / segmented-button widget support for v1.6 skin engine.
/// Delegates individual item rendering to the skin engine.
class MultipleWidget extends StatelessWidget {
  final WidgetConfig config;
  final int value;
  final ValueChanged<int> onChanged;
  final double scale;

  const MultipleWidget({
    super.key,
    required this.config,
    required this.value,
    required this.onChanged,
    this.scale = 1.0,
  });

  String get _folder => config.variant == 1 ? 'multiple_select' : 'multiple_button';

  @override
  Widget build(BuildContext context) {
    final items = config.multipleItems;
    if (items.isEmpty) return const SizedBox.shrink();

    final bool isBitmask = config.variant == 1;

    return LayoutBuilder(builder: (context, constraints) {
      final isHorizontal = config.w >= config.h;

      final dividers = <Widget>[];
      for (int i = 0; i < items.length; i++) {
        final bool isActive = isBitmask 
            ? (value & (1 << i)) != 0 
            : (value == i);

        dividers.add(
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (isBitmask) {
                  final newValue = isActive ? (value & ~(1 << i)) : (value | (1 << i));
                  onChanged(newValue);
                } else {
                  if (!isActive) onChanged(i);
                }
              },
              child: DynamicSkinRenderer(
                widgetFolder: _folder,
                layer: 'item',
                state: RKSkinState(
                  isOn: isActive,
                  styleIndex: config.style,
                  value: i / (items.length - 1), 
                  label: items[i].label,
                  icon: items[i].icon,
                  scale: scale,
                ),
              ),
            ),
          ),
        );
      }

      final content = isHorizontal 
          ? Row(children: dividers) 
          : Column(children: dividers);

      return Stack(
        children: [
          DynamicSkinRenderer(
            widgetFolder: _folder,
            layer: 'base',
            state: RKSkinState(
              styleIndex: config.style,
              isOn: value != 0,
              label: config.label,
              icon: config.icon,
              scale: scale,
            ),
          ),
          Positioned.fill(child: content),
        ],
      );
    });
  }
}
