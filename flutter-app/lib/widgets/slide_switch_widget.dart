import 'package:flutter/material.dart';
import '../models/widget_config.dart';
import '../models/protocol.dart';
import '../theme/app_theme.dart';

class SlideSwitchWidget extends StatelessWidget {
  final WidgetConfig config;
  final int value;
  final ValueChanged<int> onChanged;

  const SlideSwitchWidget({
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
      default: return Theme.of(context).colorScheme.primary;
    }
  }

  String get _stateLabel {
    final active = value != 0;
    if (active && config.onText.isNotEmpty) return config.onText;
    if (!active && config.offText.isNotEmpty) return config.offText;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final active = value != 0;
    final activeCol = _activeColor(context);
    final trackH = 14.0;
    final thumbR = trackH * 0.55;
    final trackCol = active
        ? activeCol.withValues(alpha: 0.5)
        : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3);

    return GestureDetector(
      onTap: () => onChanged(active ? 0 : 1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                const SizedBox(height: 4),
              ],
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (config.offText.isNotEmpty) ...[
                    Text(
                      config.offText,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: !active
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).disabledColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    width: thumbR * 2 + trackH * 2.2,
                    height: trackH,
                    decoration: BoxDecoration(
                      color: trackCol,
                      borderRadius: BorderRadius.circular(trackH / 2),
                    ),
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          left: active
                              ? (thumbR * 2 + trackH * 2.2) - thumbR * 2 - 2
                              : 2,
                          top: (trackH - thumbR * 2) / 2,
                          child: Container(
                            width: thumbR * 2,
                            height: thumbR * 2,
                            decoration: BoxDecoration(
                              color: active
                                  ? activeCol
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (config.onText.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      config.onText,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: active
                            ? activeCol
                            : Theme.of(context).disabledColor,
                      ),
                    ),
                  ],
                ],
              ),
              if (_stateLabel.isNotEmpty && config.onText.isEmpty && config.offText.isEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  _stateLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: activeCol,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
