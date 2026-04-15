import 'package:flutter/material.dart';
import '../models/widget_config.dart';
import '../theme/app_theme.dart';

/// LED indicator widget.
///
/// Displays a colored circle based on the LED state value:
///   0 = off (grey), 1 = red, 2 = green, 3 = blue, 4 = yellow
class LedWidget extends StatelessWidget {
  final WidgetConfig config;
  final int value;

  const LedWidget({
    super.key,
    required this.config,
    required this.value,
  });

  Color get _ledColor => AppColors.ledColor(value);
  bool get _isOn => value != 0;

  String get _colorName {
    switch (value) {
      case 1:
        return 'Red';
      case 2:
        return 'Green';
      case 3:
        return 'Blue';
      case 4:
        return 'Yellow';
      default:
        return 'Off';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isOn ? _ledColor.withValues(alpha: 0.5) : Theme.of(context).dividerColor,
          width: 1.5,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Size the LED circle proportionally to the allocated canvas space,
          // capped so it never looks absurd in very large allocations.
          final ledSize = (constraints.maxWidth * 0.45).clamp(16.0, 72.0);
          return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // LED circle with glow effect
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: ledSize,
            height: ledSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _ledColor,
              boxShadow: _isOn
                  ? [
                      BoxShadow(
                        color: _ledColor.withValues(alpha: 0.8),
                        blurRadius: 14,
                        spreadRadius: 3,
                      ),
                      BoxShadow(
                        color: _ledColor.withValues(alpha: 0.4),
                        blurRadius: 28,
                        spreadRadius: 6,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: _isOn
                ? const Center(
                    child: SizedBox(
                      width: 10,
                      height: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white30,
                        ),
                      ),
                    ),
                  )
                : null,
          ),

          if (config.label.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              config.label,
              style: TextStyle(
                color: _isOn ? Theme.of(context).textTheme.titleMedium?.color : Theme.of(context).disabledColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 2),
          Text(
            _colorName,
            style: TextStyle(
              color: _isOn ? _ledColor : Theme.of(context).disabledColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ],
      );
        },
      ),
    );
  }
}
