import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'skin_renderer.dart';
import '../skin_manager.dart';

/// A skin renderer that uses native Flutter widgets to visualize 
/// widget state and metadata without requiring external assets.
class DebugSkinRenderer extends SkinRenderer {
  const DebugSkinRenderer({
    super.key,
    required super.widgetFolder,
    required super.state,
    super.layer,
  });

  @override
  Widget build(BuildContext context) {
    final manager = SkinManager();
    final manifest = manager.current;
    if (manifest == null) return const SizedBox.shrink();

    final style = manifest.tokens.styles[state.styleIndex] ?? 
                  manifest.tokens.styles[0]!;
    
    final accentColor = state.colorOverride ?? style.primary;
    final textColor = manifest.tokens.colors['onSurface'] ?? Colors.black;
    final outlineColor = manifest.tokens.colors['outline'] ?? Colors.grey;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: outlineColor.withOpacity(0.3), width: 1),
        color: (manifest.tokens.colors['surface'] ?? Colors.white).withOpacity(0.1),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background visualization based on widget type
          _buildVisual(accentColor),
          
          // Metadata overlay
          Positioned(
            top: 2,
            left: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _debugText(widgetFolder.toUpperCase(), textColor, size: 8, bold: true),
                if (layer != null) _debugText('LAYER: $layer', textColor, size: 7),
              ],
            ),
          ),

          // State overlay
          Positioned(
            bottom: 2,
            right: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (state.isOn) _debugText('ON', Colors.green, size: 8, bold: true),
                if (state.isPressed) _debugText('PRESSED', Colors.orange, size: 8, bold: true),
                _debugText('VAL: ${state.value.toStringAsFixed(2)}', textColor, size: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisual(Color color) {
    switch (widgetFolder) {
      case 'knob':
        return Center(
          child: CustomPaint(
            size: const Size(double.infinity, double.infinity),
            painter: _KnobPainter(value: state.value, color: color),
          ),
        );
      case 'slider':
        return FractionallySizedBox(
          heightFactor: state.value.clamp(0.01, 1.0),
          widthFactor: 1.0,
          alignment: Alignment.bottomCenter,
          child: Container(color: color.withOpacity(0.4)),
        );
      case 'led':
        return Center(
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: state.isOn ? color : color.withOpacity(0.2),
              boxShadow: state.isOn ? [
                BoxShadow(color: color, blurRadius: 10, spreadRadius: 2)
              ] : null,
            ),
          ),
        );
      case 'button_push':
      case 'button_toggle':
      case 'toggle_switch':
        return Container(
          color: (state.isPressed || state.isOn) 
              ? color.withOpacity(0.3) 
              : Colors.transparent,
        );
      case 'joystick':
        return Stack(
          children: [
            Center(child: Divider(color: color.withOpacity(0.2))),
            Center(child: VerticalDivider(color: color.withOpacity(0.2))),
            Align(
              alignment: Alignment(state.valueX, state.valueY),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
            ),
          ],
        );
      default:
        return const SizedBox.expand();
    }
  }

  Widget _debugText(String text, Color color, {double size = 10, bool bold = false}) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        fontFamily: 'monospace',
      ),
    );
  }
}

class _KnobPainter extends CustomPainter {
  final double value;
  final Color color;

  _KnobPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 * 0.8;

    final paint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // Background circle
    canvas.drawCircle(center, radius, paint);

    // Value active arc
    paint.color = color;
    paint.strokeCap = StrokeCap.round;
    const startAngle = 0.75 * math.pi;
    final sweepAngle = value * 1.5 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );

    // Indicator line
    final angle = startAngle + sweepAngle;
    final lineStart = center + Offset(math.cos(angle) * (radius * 0.5), math.sin(angle) * (radius * 0.5));
    final lineEnd = center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
    canvas.drawLine(lineStart, lineEnd, paint..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
