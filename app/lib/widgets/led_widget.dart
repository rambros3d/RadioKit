import 'package:flutter/material.dart';
import '../models/widget_config.dart';

/// LED widget — displays an RGB colour set by the device (v3: 4-byte output).
///
/// The device sends [R, G, B, OPACITY] as the output value.
/// [value] is either:
///   - a List<int> [r, g, b, opacity]  (v3 VAR_DATA / VAR_UPDATE)
///   - an int (legacy palette index, retained for backwards compat)
class LedWidget extends StatelessWidget {
  final WidgetConfig config;
  final dynamic value;

  const LedWidget({
    super.key,
    required this.config,
    required this.value,
  });

  Color get _color {
    if (value is List<int>) {
      final rgba    = value as List<int>;
      final r       = rgba.isNotEmpty ? rgba[0] : 0;
      final g       = rgba.length > 1 ? rgba[1] : 0;
      final b       = rgba.length > 2 ? rgba[2] : 0;
      final opacity = rgba.length > 3 ? rgba[3] : 255;
      return Color.fromARGB(opacity, r, g, b);
    }
    // Legacy: palette index
    switch (value as int) {
      case 1:  return Colors.red;
      case 2:  return Colors.green;
      case 3:  return Colors.blue;
      case 4:  return Colors.yellow;
      default: return Colors.transparent;
    }
  }

  bool get _isOn {
    if (value is List<int>) {
      final rgba = value as List<int>;
      return rgba.any((v) => v > 0);
    }
    return (value as int) != 0;
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
                        blurRadius: 12,
                        spreadRadius: 3,
                      )
                    ]
                  : null,
            ),
          ),
          if (config.label.isNotEmpty) ...
            [
              const SizedBox(height: 4),
              Text(
                config.label,
                style: Theme.of(context).textTheme.labelSmall,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
        ],
      ),
    );
  }
}
