import 'package:flutter/material.dart';
import '../models/widget_config.dart';
import '../models/protocol.dart';
import '../theme/app_theme.dart';

/// Renders a push button (momentary) or toggle button (latched) based on
/// [config.variant]: 0 = push/momentary, 1 = toggle.
class ButtonWidget extends StatelessWidget {
  final WidgetConfig config;
  final int value;
  final ValueChanged<int> onChanged;

  const ButtonWidget({
    super.key,
    required this.config,
    required this.value,
    required this.onChanged,
  });

  Color _styleColor(BuildContext context, bool active) {
    final cs = Theme.of(context).colorScheme;
    switch (config.style) {
      case kStylePrimary: return active ? AppColors.brandOrange : AppColors.brandOrange.withValues(alpha: 0.35);
      case kStyleSuccess: return active ? AppColors.connected   : AppColors.connected.withValues(alpha: 0.35);
      case kStyleWarning: return active ? Colors.amber          : Colors.amber.withValues(alpha: 0.35);
      case kStyleDanger:  return active ? AppColors.brandRed    : AppColors.brandRed.withValues(alpha: 0.35);
      case kStyleDim:     return active ? cs.onSurface.withValues(alpha: 0.4) : cs.onSurface.withValues(alpha: 0.15);
      default:            return active ? cs.primary            : cs.primary.withValues(alpha: 0.25);
    }
  }

  bool get _isToggle => config.variant == 1;

  String get _label {
    if (_isToggle) {
      if (value != 0 && config.onText.isNotEmpty)  return config.onText;
      if (value == 0 && config.offText.isNotEmpty) return config.offText;
    }
    return config.label.isNotEmpty ? config.label : config.typeName;
  }

  @override
  Widget build(BuildContext context) {
    final active   = value != 0;
    final bgColor  = _styleColor(context, active);
    final fgColor  = Theme.of(context).colorScheme.onPrimary;

    return GestureDetector(
      onTapDown:   _isToggle ? null : (_) => onChanged(1),
      onTapUp:     _isToggle ? null : (_) => onChanged(0),
      onTapCancel: _isToggle ? null : () => onChanged(0),
      onTap:       _isToggle ? () => onChanged(active ? 0 : 1) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: bgColor.withValues(alpha: 0.8),
            width: active ? 2 : 1,
          ),
          boxShadow: active
              ? [BoxShadow(color: bgColor.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)]
              : null,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (config.icon.isNotEmpty) ...
                [Icon(parseIconFromName(config.icon), color: fgColor, size: 18),
                 const SizedBox(height: 4)],
              Text(
                _label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Map simple icon name strings to Flutter [IconData].
/// Exported so [TextWidget] and others can reuse.
IconData parseIconFromName(String name) {
  switch (name.toLowerCase()) {
    case 'power':    return Icons.power_settings_new_rounded;
    case 'play':     return Icons.play_arrow_rounded;
    case 'pause':    return Icons.pause_rounded;
    case 'stop':     return Icons.stop_rounded;
    case 'forward':  return Icons.arrow_forward_rounded;
    case 'back':     return Icons.arrow_back_rounded;
    case 'up':       return Icons.arrow_upward_rounded;
    case 'down':     return Icons.arrow_downward_rounded;
    case 'home':     return Icons.home_rounded;
    case 'settings': return Icons.settings_rounded;
    case 'info':     return Icons.info_rounded;
    case 'warning':  return Icons.warning_rounded;
    case 'check':    return Icons.check_rounded;
    case 'close':    return Icons.close_rounded;
    case 'lock':     return Icons.lock_rounded;
    case 'unlock':   return Icons.lock_open_rounded;
    case 'light':    return Icons.light_mode_rounded;
    case 'fan':      return Icons.air_rounded;
    default:         return Icons.radio_button_checked_rounded;
  }
}
