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

  const MultipleWidget({
    super.key,
    required this.config,
    required this.value,
    required this.onChanged,
  });

  String get _folder => config.variant == 1 ? 'multiple_select' : 'multiple_button';

  @override
  Widget build(BuildContext context) {
    final items = config.multipleItems;
    if (items.isEmpty) return const SizedBox.shrink();

    final bool isBitmask = config.variant == 1;

    return LayoutBuilder(builder: (context, constraints) {
      final isHorizontal = constraints.maxWidth > constraints.maxHeight;

      final children = <Widget>[];
      for (int i = 0; i < items.length; i++) {
        final bool isActive = isBitmask 
            ? (value & (1 << i)) != 0 
            : (value == i);

        children.add(
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
                state: RKSkinState(
                  isOn: isActive,
                  styleIndex: config.style,
                  value: i / (items.length - 1), // Optional: individual item index normalized
                ),
              ),
            ),
          ),
        );
      }

      return isHorizontal 
          ? Row(children: children) 
          : Column(children: children);
    });
  }
}
