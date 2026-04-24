import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/rk_theme.dart';
import 'rk_multi_button.dart';

/// Bitmask multi-select group for RadioKit.
/// 
/// Allows multiple items to be selected simultaneously using a bitmask.
/// Uses the same premium "Tactical" look as [RKMultiButton].
class RKMultiSelect extends StatelessWidget {
  const RKMultiSelect({
    super.key,
    required this.items,
    required this.bitmask,
    required this.onChanged,
    this.buttonSize = 64.0,
    this.spacing = 8.0,
    this.padding = 12.0,
    this.enableHapticFeedback = true,
    this.onActiveChanged,
    this.orientation = RKAxis.horizontal,
  });

  final List<RKToggleItem> items;
  /// Bitmask where bit i corresponds to items[i].
  final int bitmask;
  final ValueChanged<int> onChanged;
  final double buttonSize;
  final double spacing;
  final double padding;
  final bool enableHapticFeedback;
  final ValueChanged<bool>? onActiveChanged;
  final RKAxis orientation;

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.trackColor, width: 1),
        borderRadius: BorderRadius.circular(tokens.borderRadius * 2.5),
        boxShadow: tokens.shadows,
      ),
      child: Listener(
        onPointerDown: (_) => onActiveChanged?.call(true),
        onPointerUp: (_) => onActiveChanged?.call(false),
        onPointerCancel: (_) => onActiveChanged?.call(false),
        child: orientation == RKAxis.horizontal 
          ? Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: _buildButtons(spacing),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: _buildButtons(spacing),
            ),
      ),
    );
  }

  List<Widget> _buildButtons(double spacing) {
    return List<Widget>.generate(items.length, (int index) {
      final isSelected = (bitmask >> index) & 1 == 1;
      final button = _RKSelectButton(
        item: items[index],
        selected: isSelected,
        size: buttonSize,
        onTap: () {
          if (enableHapticFeedback) {
            HapticFeedback.selectionClick();
          }
          // Toggle the bit at index
          onChanged(bitmask ^ (1 << index));
        },
      );

      if (index == items.length - 1) return button;
      return Padding(
        padding: orientation == RKAxis.horizontal 
            ? EdgeInsets.only(right: spacing)
            : EdgeInsets.only(bottom: spacing),
        child: button,
      );
    });
  }
}

class _RKSelectButton extends StatelessWidget {
  final RKToggleItem item;
  final bool selected;
  final double size;
  final VoidCallback onTap;

  const _RKSelectButton({
    required this.item,
    required this.selected,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    
    // Fixed shape radius based on tokens
    final double radius = tokens.borderRadius * 2.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: selected
                ? tokens.primaryGradient
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      tokens.surface.withValues(alpha: 0.8),
                      tokens.surface.withValues(alpha: 0.5),
                    ],
                  ),
            border: Border.all(
              color: selected ? Colors.transparent : tokens.trackColor,
              width: 1.0,
            ),
            boxShadow: selected ? tokens.glows : null,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.iconFor(selected),
                  size: size * 0.3,
                  color: selected ? tokens.surface : tokens.onSurface.withValues(alpha: 0.5),
                ),
                SizedBox(height: size * 0.08),
                Text(
                  item.labelFor(selected).toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? tokens.surface : tokens.onSurface.withValues(alpha: 0.5),
                    fontSize: size * 0.1,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
