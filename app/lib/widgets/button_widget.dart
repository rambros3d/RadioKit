import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/widget_config.dart';
import '../models/protocol.dart';
import '../theme/app_theme.dart';
import '../providers/skin_provider.dart';
import '../models/skin_manifest.dart';
/// Renders a push button (momentary) or toggle button (latched) based on
/// [config.variant]: 0 = push/momentary, 1 = toggle.
/// Also renders [WidgetType.Switch] entirely as a latched toggle button.
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

  Color _styleColor(SkinTokens tokens, bool active) {
    Color c(String key, Color fallback) => tokens.colors[key] ?? fallback;

    switch (config.style) {
      case kStylePrimary: return active ? c('primary', AppColors.brandOrange) : c('primary', AppColors.brandOrange).withValues(alpha: 0.35);
      case kStyleSuccess: return active ? c('success', AppColors.connected)   : c('success', AppColors.connected).withValues(alpha: 0.35);
      case kStyleWarning: return active ? c('warning', Colors.amber)          : c('warning', Colors.amber).withValues(alpha: 0.35);
      case kStyleDanger:  return active ? c('danger', AppColors.brandRed)    : c('danger', AppColors.brandRed).withValues(alpha: 0.35);
      case kStyleDim:     return active ? c('dim', Colors.grey.shade400)      : c('dim', Colors.grey.shade400).withValues(alpha: 0.15);
      default:            return active ? c('primary', AppColors.brandOrange) : c('primary', AppColors.brandOrange).withValues(alpha: 0.25);
    }
  }

  bool get _isToggle => config.variant == 1 || config.typeId == kWidgetSwitch;

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
    final tokens   = context.watch<SkinProvider>().tokens;
    final bgColor  = _styleColor(tokens, active);
    final fgColor  = Colors.white; // Or derive from background contrast

    return GestureDetector(
      onTapDown:   _isToggle ? null : (_) => onChanged(1),
      onTapUp:     _isToggle ? null : (_) => onChanged(0),
      onTapCancel: _isToggle ? null : () => onChanged(0),
      onTap:       _isToggle ? () => onChanged(active ? 0 : 1) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(tokens.borderRadius),
          border: Border.all(
            color: bgColor.withValues(alpha: 0.8),
            width: active ? tokens.borderWidth + 1 : tokens.borderWidth,
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
                style: GoogleFonts.getFont(
                  tokens.fontFamily,
                  textStyle: Theme.of(context).textTheme.labelSmall,
                  color: fgColor,
                  fontWeight: tokens.fontWeight == 'bold' || tokens.fontWeight == '700' 
                      ? FontWeight.bold 
                      : (tokens.fontWeight == '900' ? FontWeight.w900 : FontWeight.normal),
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
