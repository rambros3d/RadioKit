import 'package:flutter/material.dart';
import '../models/widget_config.dart';
import '../models/protocol.dart';
import '../theme/app_theme.dart';

/// Toggle switch widget — renders a Material-style switch.
/// onText / offText from [config] are shown if present.
class SwitchWidget extends StatelessWidget {
  final WidgetConfig config;
  final int value;
  final ValueChanged<int> onChanged;

  const SwitchWidget({
    super.key,
    required this.config,
    required this.value,
    required this.onChanged,
  });

  Color _trackColor(BuildContext context, bool active) {
    switch (config.style) {
      case kStyleSuccess: return active ? AppColors.connected  : AppColors.connected.withValues(alpha: 0.3);
      case kStyleWarning: return active ? Colors.amber         : Colors.amber.withValues(alpha: 0.3);
      case kStyleDanger:  return active ? AppColors.brandRed   : AppColors.brandRed.withValues(alpha: 0.3);
      case kStylePrimary: return active ? AppColors.brandOrange: AppColors.brandOrange.withValues(alpha: 0.3);
      default:
        return active
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline;
    }
  }

  String get _stateLabel {
    final active = value != 0;
    if (active  && config.onText.isNotEmpty)  return config.onText;
    if (!active && config.offText.isNotEmpty) return config.offText;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final active = value != 0;
    final trackCol = _trackColor(context, active);

    return GestureDetector(
      onTap: () => onChanged(active ? 0 : 1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: FittedBox(
          fit: BoxFit.contain,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (config.label.isNotEmpty) ...[
                Text(
                  config.label,
                  style: Theme.of(context).textTheme.labelSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
              ],
              Switch(
                value: active,
                onChanged: (v) => onChanged(v ? 1 : 0),
                activeColor: trackCol,
                activeTrackColor: trackCol.withValues(alpha: 0.5),
                inactiveThumbColor: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
                inactiveTrackColor:
                    Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              ),
              if (_stateLabel.isNotEmpty)
                Text(
                  _stateLabel,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: trackCol),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
