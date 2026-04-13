import 'package:flutter/material.dart';
import '../models/widget_config.dart';

/// LED widget — displays an RGB colour set by the device.
///
/// v3 wire format: [STATE(1), R(1), G(1), B(1), OPACITY(1)]
/// STATE != 0 means the LED is on (device-side flag).
class LedWidget extends StatelessWidget {
  final WidgetConfig config;

  /// Expected: List<int> [state, r, g, b, opacity]
  final dynamic value;

  const LedWidget({
    super.key,
    required this.config,
    required this.value,
  });

  // v3: index 0 = STATE, 1 = R, 2 = G, 3 = B, 4 = OPACITY
  bool get _isOn {
    if (value is List<int>) {
      final v = value as List<int>;
      return v.isNotEmpty && v[0] != 0;
    }
    return (value as int) != 0;
  }

  Color get _color {
    if (value is List<int>) {
      final v       = value as List<int>;
      final r       = v.length > 1 ? v[1] : 0;
      final g       = v.length > 2 ? v[2] : 0;
      final b       = v.length > 3 ? v[3] : 0;
      final opacity = v.length > 4 ? v[4] : 255;
      return Color.fromARGB(opacity, r, g, b);
    }
    // Legacy palette index fallback
    switch (value as int) {
      case 1:  return Colors.red;
      case 2:  return Colors.green;
      case 3:  return Colors.blue;
      case 4:  return Colors.yellow;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final col = _color;
    final on  = _isOn;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: FittedBox(
        fit: BoxFit.contain,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: on ? col : col.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  boxShadow: on
                      ? [
                          BoxShadow(
                            color: col.withValues(alpha: 0.7),
                            blurRadius: 18,
                            spreadRadius: 4,
                          ),
                        ]
                      : null,
                ),
              ),
              if (config.label.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  config.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
