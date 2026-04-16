import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
        child: FittedBox(
          fit: BoxFit.contain,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (config.icon.isNotEmpty) ...[
                Icon(parseIconFromName(config.icon), color: fgColor, size: 18),
                const SizedBox(height: 4)
              ],
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

/// Map simple icon name strings to Lucide [IconData].
/// Exported so [TextWidget] and others can reuse.
IconData parseIconFromName(String name) {
  switch (name.toLowerCase()) {
    case 'power':      return LucideIcons.power;
    case 'play':       return LucideIcons.play;
    case 'pause':      return LucideIcons.pause;
    case 'stop':       return LucideIcons.square;
    case 'forward':    return LucideIcons.arrowRight;
    case 'back':       return LucideIcons.arrowLeft;
    case 'up':          return LucideIcons.arrowUp;
    case 'down':        return LucideIcons.arrowDown;
    case 'home':        return LucideIcons.house;
    case 'settings':    return LucideIcons.settings;
    case 'info':        return LucideIcons.info;
    case 'warning':     return LucideIcons.triangleAlert;
    case 'check':       return LucideIcons.check;
    case 'close':       return LucideIcons.x;
    case 'lock':        return LucideIcons.lock;
    case 'unlock':      return LucideIcons.lockOpen;
    case 'light':       return LucideIcons.lightbulb;
    case 'fan':         return LucideIcons.fan;
    case 'wifi':        return LucideIcons.wifi;
    case 'autorenew':
    case 'refresh':     return LucideIcons.refreshCw;
    case 'hand':        return LucideIcons.hand;
    case 'receipt':     return LucideIcons.receipt;
    case 'volume_off':
    case 'volume-x':    return LucideIcons.volumeX;
    case 'cpu':         return LucideIcons.cpu;
    case 'file-text':   return LucideIcons.fileText;
    case 'trash':       return LucideIcons.trash2;
    default:            return LucideIcons.circle;
  }
}
