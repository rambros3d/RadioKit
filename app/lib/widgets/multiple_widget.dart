import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/widget_config.dart';
import '../models/protocol.dart';
import '../theme/app_theme.dart';
import 'button_widget.dart'; // For parseIconFromName

/// Multiple / segmented-button widget for [kWidgetMultiple].
///
/// The device advertises up to 8 items via the pipe-delimited [config.content]
/// string (e.g. "Off|Low|Med|High"). The selected index (0-based) is stored in
/// the single input byte.
///
/// Layout is horizontal when the widget is wider than it is tall,
/// vertical otherwise.
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

  Color _activeColor(BuildContext context) {
    switch (config.style) {
      case kStyleSuccess: return AppColors.connected;
      case kStyleWarning: return Colors.amber;
      case kStyleDanger:  return AppColors.brandRed;
      case kStylePrimary: return AppColors.brandOrange;
      default:            return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = config.multipleItems;
    if (items.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Center(
          child: Text(
            config.label.isNotEmpty ? config.label : 'Multiple',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      );
    }

    final activeCol = _activeColor(context);

    return LayoutBuilder(builder: (context, constraints) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
        ),
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: config.variant * 60.0, // Base width based on items
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (config.label.isNotEmpty) ...[
                  Text(
                    config.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                  ),
                  const SizedBox(height: 4),
                ],
                // Header (Switch style row or grid depending on variant)
                SizedBox(
                  height: 32,
                  child: Row(
                    children: _buildItems(context, items, activeCol, true),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  List<Widget> _buildItems(BuildContext context, List<MultipleItem> items,
      Color activeCol, bool horizontal) {
    final List<Widget> children = [];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final isActive = value == i;
      if (i > 0) {
        children.add(horizontal
            ? const SizedBox(width: 3)
            : const SizedBox(height: 3));
      }
      children.add(
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              decoration: BoxDecoration(
                color: isActive ? activeCol : activeCol.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: isActive ? activeCol : activeCol.withValues(alpha: 0.3),
                  width: isActive ? 1.5 : 1,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (item.icon.isNotEmpty) ...[
                      Icon(
                        parseIconFromName(item.icon),
                        size: 14,
                        color: isActive
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      if (item.label.isNotEmpty) const SizedBox(width: 4),
                    ],
                    if (item.label.isNotEmpty)
                      Flexible(
                        child: Text(
                          item.label,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: isActive
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.75),
                                fontWeight:
                                    isActive ? FontWeight.bold : FontWeight.normal,
                              ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return children;
  }
}
